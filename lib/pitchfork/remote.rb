# frozen_string_literal: true

%w[
  pitchfork
].each { |lib| require lib }

class Pitchfork::Remote
  include Pitchfork::Logging

  attr_reader *%i[name user_name repo_name provider repository url]

  def initialize(name, auth, provider, user_name, repo_name)
    @name       = name
    @provider   = provider
    @user_name  = user_name
    @repo_name  = repo_name
    @repository = get_repository
    @url        = auth == 'ssh' ? repository.ssh_url : repository.clone_url
  end

  private

  def get_repository
    log_info { "Getting a repository info from #{provider.api_endpoint}#{user_name}/#{repo_name}" }
    provider.repository(user: user_name, repo: repo_name)
  end
end
