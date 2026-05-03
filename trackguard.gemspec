require_relative "lib/trackguard/version"

Gem::Specification.new do |s|
  s.name        = "trackguard"
  s.version     = Trackguard::VERSION
  s.summary     = "Visitor tracking Rails Engine"
  s.authors     = [ "Krzysztof Rygielski" ]
  s.email       = [ "krzysztof@rygiel.net" ]
  s.homepage    = "https://github.com/riggy/trackguard"
  s.license     = "MIT"
  s.files       = Dir["{app,config,db,lib}/**/*", "trackguard.gemspec"]
  s.require_paths = [ "lib" ]
  s.required_ruby_version = ">= 3.2"

  s.add_dependency "rack-attack"
  s.add_dependency "rails", ">= 8.1"
  s.metadata["rubygems_mfa_required"] = "true"
end
