# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'http_pack/version'

Gem::Specification.new do |spec|
  spec.name          = "http_pack"
  spec.version       = HttpPack::VERSION
  spec.authors       = ["codemeow5"]
  spec.email         = ["codemeow@icloud.com"]

  spec.summary       = %q{Ruby HttpPack server-side plugin}
  spec.description   = %q{Used for guaranteed data transfer between servers.}
  spec.homepage      = "https://github.com/codemeow5/ruby-httppack"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rack"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
  
  spec.add_runtime_dependency "redis", "~>3.2"
  spec.add_runtime_dependency "redis-namespace"
  spec.add_runtime_dependency "ruby_deep_clone", "~> 0.7.2"
  spec.add_runtime_dependency 'connection_pool', '~> 2.2', '>= 2.2.1'
end
