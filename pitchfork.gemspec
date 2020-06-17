# frozen_string_literal: true

require_relative 'lib/pitchfork/version'

Gem::Specification.new do |spec|
  spec.name    = 'pitchfork'
  spec.version = Pitchfork::VERSION
  spec.author  = 'Alexander Zagaynov'
  spec.email   = 'zalex80@gmail.com'

  spec.summary     = 'Tool for mass forking and updating a set of repos'
  spec.description = 'Pitchfork is an open source cli tool to help developer with the forking workflow.'

  spec.homepage = 'https://alexanderzagaynov.github.io/pitchfork'
  spec.license  = 'Apache-2.0'

  spec.metadata = {
    'homepage_uri'      => spec.homepage,
    'changelog_uri'     => "https://github.com/AlexanderZagaynov/pitchfork/releases/tag/v#{spec.version}",
    'source_code_uri'   => 'https://github.com/AlexanderZagaynov/pitchfork',
    'bug_tracker_uri'   => 'https://github.com/AlexanderZagaynov/pitchfork/issues',
    'allowed_push_host' => 'TBD',
  }.freeze

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.add_dependency 'dotenv'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'octokit'
  spec.add_dependency 'git'

  spec.required_ruby_version = Gem::Requirement.new('~> 2.7.0')
end
