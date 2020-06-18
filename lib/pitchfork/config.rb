# frozen_string_literal: true

%w[
  yaml
  ostruct
  pathname
  active_support/core_ext/hash
  active_support/core_ext/object/blank
  active_support/core_ext/module/delegation
  pitchfork
  pitchfork/github
].each { |lib| require lib }

class Pitchfork::Config
  include Pitchfork::Logging

  using (Module.new do
    refine Hash do
      def to_struct
        hsh = dup
        hsh.each do |key, value|
          hsh[key] = value.to_struct if value.is_a?(Hash)
        end
        OpenStruct.new(hsh)
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
  delegate *%i[hosts repos], to: :config

  def initialize
    find_config_files!
    load_config_files!
    configure_hosts!
    configure_repos!
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
    end.tap do |cfg|
      cfg.reverse_merge!('hosts' => {}, 'repos' => {})

      defaults = cfg.delete('defaults') || {}
      defaults.each_pair do |cfg_name, cfg_value|
        cfg[cfg_name].each_value { |c| c.reverse_merge!(cfg_value) }
      end

      log_debug { "Final config: \n#{cfg.to_yaml}" }
    end.to_struct.freeze
  end

  def configure_hosts!
    hosts.each_pair do |host_name, host|
      token = ENV["#{host_name.upcase}_TOKEN"]

      if token.present?
        host.provider = Pitchfork::Github.new(host, token) # TODO: different providers
      else
        log_warn { "Missing token for #{host.name}" }
      end

      host.freeze
    end
    hosts.freeze
  end

  def configure_repos!
    repos.each_pair do |repo_name, repo|
      repo.name     = repo_name
      repo.host     = hosts[repo.host]
      repo.provider = repo.host.provider

      if repo.provider.present?
        repo.user = repo.provider.login
        repo.origin, repo.upstream = repo.provider.get_remotes(repo.name, repo.user, repo.owner)
      else
        log_error { "Missing provider for repo '#{repo.name}'" }
      end

      repo.freeze
    end
    repos.freeze
  end
end
