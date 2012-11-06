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

  describe "#remaining, #done?" do
    it "should be ~25 on start" do
      pomux.start
      pomux.remaining.should == 25
      pomux.should_not be_done
    end

    it "should say how much time is remaining" do
      pomux.start
      Timecop.travel(Time.now + 25*60)
      pomux.remaining.should <= 0
      pomux.should be_done
    end
  end
end
