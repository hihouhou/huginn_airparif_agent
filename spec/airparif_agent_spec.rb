require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::AirparifAgent do
  before(:each) do
    @valid_options = Agents::AirparifAgent.new.default_options
    @checker = Agents::AirparifAgent.new(:name => "AirparifAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
