# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'

Bundler.require(*%i[default test])

AmazingPrint.defaults = { indent: -2, sort_keys: true }
AmazingPrint.pry!

require 'pitchfork'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
