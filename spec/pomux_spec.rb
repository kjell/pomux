# encoding: utf-8
require 'spec_helper'

describe Pomux do
  let(:pomux) { Pomux.new }
  let(:path) { File.expand_path('../.pomux', __FILE__) }
  let(:notifications) { [] }
  before do
    Timecop.freeze
    pomux.stub!(:path) { path }
    pomux.stub!(:testing?) { true }
    Process.stub(:spawn).with(any_args()) do |args|
      notifications << args
    end
    FileUtils.cp('spec/fixtures/pomux_not_started', 'spec/.pomux')
  end

  after do
    Timecop.return
    FileUtils.rm(path)
    notifications.clear
  end

  it "should write ~/.pomux to spec/.pomux when testing" do
    File.exists?(path).should be_true
  end

  describe "#start" do
    subject { pomux.start; pomux }

    it { should be_started }
    its(:started) { should == Time.now }
    its(:count) { should == 0 }
    its(:ended) { should_not == Time.now } # TODO: Bad test. Write the pomux fixture in setup instead of copying one with the same ended:

    it "should change #started" do
      lambda { pomux.start }.should change(pomux, :started)
    end

    it "should notify" do
      Process.should_receive(:spawn).exactly(3).times
      pomux.start
      notifications.should have(3).items
      [/growlnotify/, /refresh-client/, /killall Mail/].each do |note|
        notifications.grep(note).should_not be_nil
      end
    end

    it "shouldn't start if already #started?" do
      pomux.should_not_receive(:save)
      pomux.stub(:started?) { true }
      lambda { pomux.start }.should_not change(pomux, :started)
      notifications.should be_empty
    end

    context "with a slip" do
      it "should start the pomux <slip> minutes ago" do
        pomux.start_minus_5
        pomux.started.should == Time.now - 60*5
      end
    end
  end

  describe "#info" do
    subject { pomux.info }

    it "should track :started, :count, and :last" do
      pomux.info['started'].should be_nil
      pomux.info['count'].should == 0
      pomux.info['last'].should be_a_kind_of(Time)
    end
  end

  describe "#elapsed" do
    it "should tell how long since the last pomux ended" do
      pomux.abort
      pomux.elapsed.should == 0
      Timecop.travel(Time.now + 60*45)
      pomux.elapsed.should be_within(0.001).of(45)
    end
  end

  describe "#started?" do
    it "should be true after starting" do
      pomux.should_not be_started
      pomux.start
      pomux.should be_started
    end

    it "should be false after aborting" do
      pomux.start
      pomux.should be_started
      pomux.abort
      pomux.should_not be_started
    end

    it "should change to false after polling once time is up" do
      pomux.stub(:done?).once { true }
      pomux.start
      Timecop.travel(Time.now + 60*45)
      pomux.should be_started
      pomux.poll
      pomux.should_not be_started
    end
  end

  describe "#remaining, #done?, #progress" do
    before { Timecop.freeze; pomux.start }
    subject { pomux }

    context "at the start" do
      it { should be_done_in('25m') }
      it { should_not be_done }
    end

    context "after 1 minute" do
      before { Timecop.travel(1 * 60) }
      it { should be_done_in('24m') }
      it { should_not be_done }
    end

    context "after 24 minutes" do
      before { Timecop.travel(24 * 60) }
      it { should be_done_in('1m') }
      it { should_not be_done }
    end

    context "after 25 minutes" do
      before { Timecop.travel(25 * 60) }
      it { should be_done_in([/[⇈  ᚚ  ⇶]/, 0]) }
      it { should be_done }
    end

    context "after 5m of break" do
      before { pomux.done!; Timecop.travel(6 * 60) }
      let(:counters) {%w(⦿ ➊ ➋ ➌ ➍ ➎ ➏ ➐ ➑ ➒ ➓)}

      (0..10).each do |count|
        context("after #{count} pomuxes") do
          before { pomux.stub(:count) { count } }
          its(:progress) { should == counters[count] }
        end
      end
    end
  end

  describe "#poll" do
    subject { pomux.poll }
    context "when on break" do
      it { should be_nil }
    end
    context "when started" do
      before { pomux.start; Timecop.travel(5*60) }
      it { should == 20 }
    end
    context "when done" do
      before { pomux.start; Timecop.travel(25*60) }
      it { should == 0 }
    end
  end

  describe "#done!" do
    context "when inside a pomux" do
      before { pomux.start }

      it "should increment the count" do
        lambda {pomux.done!}.should change(pomux, :count).by(1)
      end

      it "should reset started and record last" do
        pomux.done!
        pomux.started.should be_nil
        pomux.ended.should == Time.now
      end
    end

    it "should only happen once when called multiple times" do
      pomux.stub(:save).once
      pomux.done!
      pomux.done!
    end

    context "when not running a pomux" do
      it "shouldn't have any effect" do
        lambda {pomux.done!}.should_not change(pomux, :count)

        pomux.ended.should_not == Time.now
      end
    end
  end

  describe "#reset" do
    context "when not started" do
      it "doesn't reset when not started" do
        pomux.stub(:save).never
        pomux.reset
      end

      it "unless #count > 0" do
        pomux.info['count'] = 3 # How do I stub a method once?
        lambda { pomux.reset }.should change(pomux, :count).to(0)
      end
    end

    context "when started" do
      before { pomux.info['count'] = 3; pomux.start }

      it "resets the count" do
        lambda { pomux.reset }.should change(pomux, :count).to(0)
      end
    end
  end

  describe "#report" do
    it "should echo #progress" do
      pomux.report.should == pomux.progress
    end
  end

  describe "#growl" do
    before { pomux.growl }
    subject { notifications }
    it { should have(2).notifications }
  end

  describe "#log" do
    before do
      Timecop.freeze
      GitLogger.any_instance.stub(:log) { "Git commit info" }
    end
    subject { pomux }

    context "with nothing accomplished" do
      before { pomux.stub(:count) { 0 }; pomux.abort; pomux.log }
      its(:ended) { should == Time.now }
      its(:log_string) { should =~ /0m/ }
      its(:log_string) { should =~ /---/ }
      it "originates 4 notifications" do # TODO: Split notifications and Process.spawns
        notifications.should have(4).items
      end
      its(:loggers) { should == [PomuxLogger, GitLogger, DayOneLogger] }
    end

    context "with count > 0" do
      before { pomux.stub(:count) { 2 }; pomux.abort; pomux.log }
      its(:log_string) { should =~ /60m/ }

      context "plus some extra time" do
        before { pomux.stub(:elapsed) { 5 }; pomux.log}
        its(:log_string) { should =~ /\+ 5m/ }
      end
    end

    it "should include git commits" do
      pomux.log
      pomux.log_string.should =~ /Git commit info/
    end

    context "with a custom logger" do
      class StarLogger < PomuxLogger
        def log
          '****'
        end
      end
      before { pomux.stub(:loggers) {[StarLogger]}; pomux.log }

      its(:loggers) { should include(StarLogger) }
      its(:log_string) { should =~ /\*+/ }
    end

    context "DayOneLogger" do
      before { pomux.stub(:loggers) {[DayOneLogger]}; pomux.log }

      it "should create two more notifications" do
        notifications.should have(2).items
      end
    end
  end
end
