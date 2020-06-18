# frozen_string_literal: true

%w[
  pitchfork/version
  pitchfork/logging
].each { |lib| require lib }

module Pitchfork
  class Error < StandardError; end

    # Dotenv.load('~/work/.env')

    # config.hosts.each_pair do |host_name, host|
    #   token = ENV["#{host_name.upcase}_TOKEN"]
    #   unless token.present?
    #     puts "Missing token for #{host.name}"
    #     next
    #   end
    #   options = { access_token: token }
    #   options[:api_endpoint] = "https://#{host.api_endpoint}/api/v3/" if host.api_endpoint.present?
    #   host.client = Octokit::Client.new(options) # TODO: different providers
    #   host.user   = host.client.user.freeze # .to_hash.to_struct.freeze
    # end
end
