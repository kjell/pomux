POMUX_TESTING = true
require File.expand_path('../../lib/pomux', __FILE__)
require 'rspec'

RSpec::Matchers.define :be_done_in do |expected|
  match do |actual|
    progress, remaining = expected
    remaining ||= expected.to_i
    actual.poll.should == remaining
    if progress.kind_of?(Regexp)
      actual.progress.should =~ progress
    else
      actual.progress.should == progress
    end
  end

  failure_message_for_should do |actual|
    "expected pomux to finish in #{expected}, it says #{actual.progress}"
  end
end
