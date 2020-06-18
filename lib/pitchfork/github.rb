# frozen_string_literal: true

%w[
  octokit
  active_support/core_ext/module/delegation
  pitchfork
].each { |lib| require lib }

class Pitchfork::Github
  attr_reader *%i[host client user]

  def initialize(host, token)
    @host = host

    options = { access_token: token }
    options[:api_endpoint] = "https://#{host.api_endpoint}/api/v3/" if host.api_endpoint.present?

    @client = Octokit::Client.new(options)
    @user   = client.user.freeze
  end

  delegate :login, to: :user, allow_nil: true

  def get_remote_url(remote)
    host.auth == 'ssh' ? remote.ssh_url : remote.clone_url
  end

  def get_remote(repo, user)
    client.repository(user: user, repo: repo)
  rescue Octokit::NotFound
    raise Pitchfork::RemoteNotFound # rebrand the error, keeping all info
  end

  def get_remotes(repo, user, owner = nil)
    # if already cloned then fetch
    # else try to clone origin
    # if its not present then fork if has owner
    # clone after fork
    # if has upstream then add to remotes and fetch
    if owner.present?
    end
  end

  def fork_upstream(repo, owner)
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
end
