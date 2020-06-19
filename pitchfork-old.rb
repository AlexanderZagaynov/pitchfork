#!/usr/bin/env ruby
# frozen_string_literal: true

## check for the forks first

threads = {}
MAX_RETRIES = 4
SLEEP_INTERVAL = 15

config.repos.each_pair do |repo_name, repo|

  begin
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

puts 'Done!'
