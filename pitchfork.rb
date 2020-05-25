#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(*%i[default development])

AmazingPrint.defaults = { indent: -2, sort_keys: true }

%w[
  yaml
  ostruct
  fileutils
  active_support/core_ext/hash
  active_support/core_ext/object/blank
].each { |lib| require lib }

CONFIG_FILES = %w[
  .pitchfork.{yml,yaml}
  .pitchfork.*.{yml,yaml}
].freeze

module HashUtils
  refine Hash do
    def to_struct
      hash = dup
      hash.each do |key, value|
        hash[key] = value.to_struct if value.is_a?(Hash)
      end
      OpenStruct.new(hash)
    end
  end
end
using HashUtils

def get_remote_url(host, owner, repo_name)
  remote_repo = host.client.repository("#{owner}/#{repo_name}")
  host.auth == 'ssh' ? remote_repo.ssh_url : remote_repo.clone_url
end

def check_remote(local_repo, remote_name, remote_url, repo_name)
  if local_repo.remotes.map(&:name).include?(remote_name) # TODO: better check
    local_remote_url = local_repo.remote(remote_name).url
    unless local_remote_url == remote_url
      puts "Fixing #{remote_name} url for #{repo_name}, was: #{local_remote_url}"
      local_repo.set_remote_url(remote_name, remote_url)
    end
  else
    puts "Adding #{remote_name} to #{repo_name}, url: #{remote_url}"
    local_repo.add_remote(remote_name, remote_url)
  end

  puts "Updating #{remote_name} of #{local_repo.dir.path} from #{remote_url}"
  local_repo.fetch(remote_name)
end

config = Dir.glob(CONFIG_FILES).each_with_object({}) do |file, memo|
  memo.deep_merge! YAML.load_file(file, fallback: {})
end.to_struct.freeze

config.hosts.each_pair do |host_name, host|
  token = ENV["#{host_name.upcase}_TOKEN"]
  unless token.present?
    puts "Missing token for #{host.name}"
    next
  end
  options = { access_token: token }
  options[:api_endpoint] = "https://#{host.api_endpoint}/api/v3/" if host.api_endpoint.present?
  host.client = Octokit::Client.new(options) # TODO: different providers
  host.user   = host.client.user.freeze # .to_hash.to_struct.freeze
end

## check for forks first

threads = {}
MAX_RETRIES = 4
SLEEP_INTERVAL = 15

config.repos.each_pair do |repo_name, repo|
  config.defaults.repos.each_pair do |attr_name, attr_value|
    repo[attr_name] ||= attr_value
  end
  repo.host = config.hosts[repo.host]
  unless repo.host[:client].present?
    puts "Missing client for repo '#{repo_name}'"
    next
  end
  repo.owner ||= repo.host.user.login

  begin
    repo.origin_url = get_remote_url(repo.host, repo.owner, repo_name)
  rescue Octokit::NotFound ## TODO: Pitchfork::NotFound
    if repo.upstream.present?
      thread = threads[repo] = Thread.new("#{repo.upstream}/#{repo_name}") do |full_name|
        repo.host.client.fork(full_name)

        retries = MAX_RETRIES
        begin # wait for fork to finish
          sleep SLEEP_INTERVAL
          puts "Checking for #{full_name} fork to complete..."
          repo.origin_url = get_remote_url(repo.host, repo.owner, repo_name)
        rescue Octokit::NotFound
          if retries > 0
            retries -= 1
            retry
          else
            raise
          end
        end
      end
      thread.abort_on_exception = true
    else
      raise
    end
  end
end

if threads.present?
  puts "Waiting for the host forks to finish"
  threads.each_value(&:join)
end

##

config.repos.each_pair do |repo_name, repo|
  repo.path = File.expand_path(repo.path || repo_name.to_s, repo.base_dir || File.pwd)

  if Dir.exist?(repo.path)
    if Dir.exist?(File.join repo.path, '.git')
      puts "Path exists: #{repo.path}"
      repo.local = Git.open(repo.path)
    elsif Dir.empty?(repo.path)
      puts "Empty path exists: #{repo.path}"
    else
      puts "Path exists, but seems incorrect: #{repo.path}"
      exit -1
    end
  elsif File.exist?(repo.path)
    puts "Path exists, but seems incorrect: #{repo.path}"
    exit -1
  else
    puts "Creating directory: #{repo.path}"
    FileUtils.mkpath(repo.path)
  end

  if Dir.empty?(repo.path)
    if repo.origin_url.present?
      puts "Clonning #{repo.origin_url} into #{repo.path}"
      repo.local = Git.clone(repo.origin_url, repo.path)
    else
      puts "Can't clone, missing origin url for repo '#{repo_name}'"
      next
    end
  else
    check_remote(repo.local, 'origin', repo.origin_url, repo_name)
  end

  if repo.upstream.present?
    upstream_url = get_remote_url(repo.host, repo.upstream, repo_name)
    check_remote(repo.local, 'upstream', upstream_url, repo_name)
  end

  # TODO: remote_repo.parent, remote_repo.fork: The parent and source objects are present when the repository is a fork.

  # TODO: check primary remote via current branch?
  # branch_name = repo.local.current_branch
  # if repo.local.remote.name

  # ap repo.local.status # TODO: check if there is any local modifications, merge updates otherwise
end

puts 'Done!'
