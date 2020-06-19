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

  class Remote # TODO: abstract and move to it's own file
    attr_reader *%i[name user_name repo_name repository url]

    def initialize(name, auth, client, user_name, repo_name)
      @name       = name
      @user_name  = user_name
      @repo_name  = repo_name
      @repository = client.repository(user: user_name, repo: repo_name)
      @url        = auth == 'ssh' ? repository.ssh_url : repository.clone_url
    end
  end

  def get_remote(name, user_name, repo_name)
    Remote.new(name, host.auth, client, user_name, repo_name)
  rescue Octokit::NotFound
    raise Pitchfork::RemoteNotFound # rebrand the error, keeping all info
  end

  def get_remotes(repo)
    # if already cloned then fetch
    # else try to clone origin
    # if its not present then fork if has owner
    # clone after fork
    # if has upstream then add to remotes and fetch

    origin   = get_remote('origin',   repo.user,  repo.name)
    upstream = get_remote('upstream', repo.owner, repo.name) if repo.owner.present?

    [origin, upstream]
  end

  def fork_upstream(repo, owner)
  end
end


# if repo.upstream.present?
#   upstream_url = get_remote_url(repo.host, repo.upstream, repo_name)
#   check_remote(repo.local, 'upstream', upstream_url, repo_name)
# end

# TODO: remote_repo.parent, remote_repo.fork: The parent and source objects are present when the repository is a fork.

# TODO: check primary remote via current branch?
# branch_name = repo.local.current_branch
# if repo.local.remote.name

# ap repo.local.status # TODO: check if there is any local modifications, merge updates otherwise
