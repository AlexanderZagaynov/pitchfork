# frozen_string_literal: true

%w[
  git
  concurrent
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
    pool = Concurrent::ThreadPoolExecutor.new(
      min_threads:     0, # 1,
      max_threads:     0, # Concurrent.processor_count,
      max_queue:       Concurrent.processor_count * 5,
      fallback_policy: :caller_runs,
      auto_terminate:  false,
      idletime:        5,
    )

    log_info { 'Starting repos processing in threads...' }
    repos.each do |repo|
      pool.post { process_repo(repo) }
    end

    log_info { 'Waiting all repo processing threads to shutdown...' }
    pool.shutdown
    pool.wait_for_termination
  end

  private

  def process_repo(repo)
    return unless check_repo_path(repo)

    if Dir.empty?(repo.path)
      clone_repo(repo)
    else
      check_remote(repo, repo.origin)
    end

    if repo.upstream.present?
      check_remote(repo, repo.upstream)

      # TODO: temporary here, refactor

      Git::Lib.prepend(Module.new do
        def symbolic_ref(ref, opts = {})
          arr_opts = []
          arr_opts << "--short" if opts[:short]
          arr_opts << ref
          command('symbolic-ref', arr_opts)
        end
      end)

      current_branch = repo.local.lib.symbolic_ref('HEAD', short: true)
      primary_branch = repo.local.lib.symbolic_ref('refs/remotes/origin/HEAD', short: true).gsub(/^origin\//, '')

      mergeable   = true
      mergeable &&= current_branch == primary_branch
      mergeable &&= repo.local.status.yield_self do |status|
        %i[added changed deleted].all? { |type| status.public_send(type).empty? }
      end

      if mergeable
        log_info { "Merging upstream changes to #{primary_branch}" }
        merge_info = repo.local.merge("upstream/#{primary_branch}")
        log_info { merge_info }
      else
        log_warn { "Skipping upstream merge for #{repo.name} repo" }
      end
    end
  end

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
