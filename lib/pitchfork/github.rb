# frozen_string_literal: true

%w[
  active_support/core_ext/module/delegation
  pitchfork
].each { |lib| require lib }

class Pitchfork::Github
  attr_reader *%i[host user repo remote url]

  def initialize(host, user, repo)
    @host = host
    @user = user
    @repo = repo

    @remote = client.repository("#{user}/#{repo}")
    @url = host.auth == 'ssh' ? remote_repo.ssh_url : remote_repo.clone_url
  end

  delegate :client, to: :host, allow_nil: true

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
end
