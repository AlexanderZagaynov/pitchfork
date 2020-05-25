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

github = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
gh_user = github.user.freeze # .to_hash.to_struct.freeze

config.hosts.github.client = github # TODO: different providers
config.hosts.github.user = gh_user

## check for forks first

threads = {}
MAX_RETRIES = 4
SLEEP_INTERVAL = 15

config.repos.each_pair do |repo_name, repo|
  repo.host = config.hosts[repo.host]
  repo.owner ||= repo.host.user.login

  begin
    repo.origin_url = get_remote_url(repo.host, repo.owner, repo_name)
  rescue Octokit::NotFound
    if repo.upstream.present?
      thread = threads[repo] = Thread.new("#{repo.upstream}/#{repo_name}") do |full_name|
        repo.host.client.fork(full_name)

        retries = MAX_RETRIES
        begin # wait for fork to finish
          sleep SLEEP_INTERVAL
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
  path = File.expand_path(repo.path)
  if Dir.exist?(path)
    if Dir.exist?(File.join path, '.git')
      puts "Path exists: #{path}"
      repo.local = Git.open(path)
    elsif Dir.empty?(path)
      puts "Empty path exists: #{path}"
    else
      puts "Path exists, but seems incorrect: #{path}"
      exit -1
    end
  elsif File.exist?(path)
    puts "Path exists, but seems incorrect: #{path}"
    exit -1
  else
    puts "Creating directory: #{path}"
    FileUtils.mkpath(path)
  end

  if Dir.empty?(path)
    puts "Clonning #{repo.origin_url} into #{path}"
    repo.local = Git.clone(repo.origin_url, path)
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
  puts 'Done!'
end
