# frozen_string_literal: true

%w[
  active_support/core_ext/module/delegation
  pitchfork
  pitchfork/config
].each { |lib| require lib }

class Pitchfork::Processor
  attr_reader :config

  def initialize
    @config = Pitchfork::Config.new
  end

  def run
  end
end
