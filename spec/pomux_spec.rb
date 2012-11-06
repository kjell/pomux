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
end
