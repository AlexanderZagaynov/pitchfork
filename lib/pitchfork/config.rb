# frozen_string_literal: true

%w[
  yaml
  ostruct
  pathname
  active_support/core_ext/hash
  active_support/core_ext/object/blank
  pitchfork
  pitchfork/github
].each { |lib| require lib }

class Pitchfork::Config
  include Pitchfork::Logging

  using (Module.new do
    refine Hash do
      def to_struct
        hash = dup
        hash.each do |key, value|
          hash[key] = value.to_struct if value.is_a?(Hash)
        end
        OpenStruct.new(hash)
      end
    end
  end)

  ROOT = Pathname(__dir__).join('../..').expand_path.freeze
  CONFIG_FILES = %w[
    .pitchfork.{yml,yaml}
    .pitchfork.*.{yml,yaml}
  ].freeze
  private_constant *%i[ROOT CONFIG_FILES]

  attr_reader *%i[config config_files]

  def initialize
    find_config_files!
    load_config_files!
    configure_hosts!
  end

  private

  def find_config_files!
    @config_files = [
      ROOT,
      Pathname(Dir.home),
      Pathname.pwd,
    ].uniq.flat_map do |base|
      base.glob(CONFIG_FILES).map(&:expand_path)
    end.freeze
    log_info { "Found config files: \n#{config_files.join("\n")}" }
  end

  def load_config_files!
    @config = config_files.each_with_object({}) do |file, memo|
      memo.deep_merge! YAML.load_file(file, fallback: {})
    end.tap do |hash|
      log_debug { "Final config: \n#{hash.to_yaml}" }
    end.to_struct.freeze
  end

  def configure_hosts!
    config.hosts.each_pair do |host_name, host|
      token = ENV["#{host_name.upcase}_TOKEN"]
      if token.blank?
        log_warn { "Missing token for #{host.name}" }
        next
      end

      options = { access_token: token }
      options[:api_endpoint] = "https://#{host.api_endpoint}/api/v3/" if host.api_endpoint.present?

      host.client = Octokit::Client.new(options) # TODO: different providers
      host.user   = host.client.user.freeze # .to_hash.to_struct.freeze

      host.freeze
    end

    config.hosts.freeze
  end
end
