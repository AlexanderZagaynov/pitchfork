# frozen_string_literal: true

%w[
  dotenv/load
  pitchfork/version
  pitchfork/logging
].each { |lib| require lib }

module Pitchfork
  class Error < StandardError; end
  class RemoteNotFound < Error; end
end
