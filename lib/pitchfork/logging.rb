# frozen_string_literal: true

%w[
  logger
  active_support/core_ext/module/delegation
].each { |lib| require lib }

module Pitchfork
  LOGGER = Logger.new(STDOUT, progname: name)

  module Logging
    delegate *LOGGER.class::Severity.constants.map(&:downcase), to: 'Pitchfork::LOGGER', prefix: 'log'
  end
end
