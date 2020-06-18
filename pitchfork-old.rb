#!/usr/bin/env ruby
# frozen_string_literal: true

## check for the forks first

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
    Pathname.mkpath(repo.path)
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
