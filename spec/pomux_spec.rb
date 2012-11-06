require 'spec_helper'

describe Pomux do
  let(:pomux) { Pomux.new }
  let(:path) { File.expand_path('../.pomux', __FILE__) }
  before do
    pomux.stub!(:path) { path }
    pomux.stub!(:testing?) { true }
    FileUtils.cp('spec/fixtures/pomux_not_started', 'spec/.pomux')
  end
  after { FileUtils.rm(path) }

  it "should write ~/.pomux to spec/.pomux when testing" do
    File.exists?(path).should be_true
  end

  describe "#start" do
    subject { pomux.start; pomux }

    its(:started) { should be_within(5).of(Time.now) }
    its(:count) { should == 0 }
    its(:ended) { should_not be_within(60*30).of(Time.now) } # TODO: Bad test. Write the pomux fixture in setup instead of copying one with the same ended:
  end

  describe "#info" do
    subject { pomux.info }
    it "should track :started, :count, and :last" do
      pomux.info['started'].should be_nil
      pomux.info['count'].should == 0
      pomux.info['last'].should be_a_kind_of(Time)
    end
  end
end
