# frozen_string_literal: true

%w[
  git
  active_support/core_ext/module/delegation
  pitchfork
  pitchfork/config
].each { |lib| require lib }

class Pitchfork::Processor
  include Pitchfork::Logging

  attr_reader :config
  delegate *%i[hosts repos], to: :config

  def initialize
    @config = Pitchfork::Config.new
  end

  def run
    repos.each do |repo|
      next unless check_repo_path(repo)

      if Dir.empty?(repo.path)
        clone_repo(repo)
      else
        check_remote(repo, repo.origin)
      end

      check_remote(repo, repo.upstream) if repo.upstream.present?
    end
  end

  private

  def check_repo_path(repo)
    if repo.path.directory?

      if repo.path.join('.git').directory?
        log_info { "Path exists: #{repo.path}" }
        repo.local = Git.open(repo.path)
        true

      elsif repo.path.empty?
        log_info { "Empty path exists: #{repo.path}" }
        true

      else
        log_error{ "Path exists, but seems incorrect: #{repo.path}" }
        false

      end

    elsif repo.path.file?
      log_error { "Path exists, but seems incorrect: #{repo.path}" }
      false

    else
      log_info { "Creating directory: #{repo.path}" }
      repo.path.mkpath
      true

    end
  end

  def clone_repo(repo)
    if repo.origin.url.present?
      log_info { "Clonning #{repo.origin.url} into #{repo.path}" }
      repo.local = Git.clone(repo.origin.url, repo.path)
    else
      log_error { "Can't clone, missing origin url for repo '#{repo.name}'" }
    end
  end

  def check_remote(repo, remote)
    if repo.local.remotes.map(&:name).include?(remote.name) # TODO: better check

      local_remote_url = repo.local.remote(remote.name).url
      unless local_remote_url == remote.url
        low_info { "Fixing #{remote.name} url for #{repo.name}, was: #{local_remote_url}" }
        repo.local.set_remote_url(remote.name, remote.url)
      end

    else
      log_info { "Adding #{remote.name} to #{repo.name}, url: #{remote.url}" }
      repo.local.add_remote(remote.name, remote.url)
    end

    log_info { "Updating #{remote.name} of #{repo.local.dir.path} from #{remote.url}" }
    repo.local.fetch(remote.name)
  end
end
