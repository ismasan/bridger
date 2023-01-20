
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "bridger/version"

Gem::Specification.new do |spec|
  spec.name          = "bridger"
  spec.version       = Bridger::VERSION
  spec.authors       = ["Ismael Celis"]
  spec.email         = ["ismaelct@gmail.com"]

  spec.summary       = %q{Write Ruby APIs like a boss}
  spec.description   = %q{Write Ruby APIs like a boss}
  spec.homepage      = "https://www.github.com/ismasan/bridger"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency "jwt", '~> 2'
  spec.add_dependency "multi_json"
  spec.add_dependency "oat"
  spec.add_dependency "parametric", ">= 0.2.17"
  spec.add_dependency 'faraday', ['>= 0.2.11', '< 2.2']
  spec.add_dependency "bootic_client", ">= 0.0.30"
  spec.add_dependency "rack", '>= 2.0.6'
  spec.add_dependency "rack-test"

  spec.add_development_dependency "sinatra", '~> 2'
  spec.add_development_dependency "actionpack", '~> 7'
  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "byebug"
end
