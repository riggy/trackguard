require_relative "lib/trackguard/version"

Gem::Specification.new do |s|
  s.name        = "trackguard"
  s.version     = Trackguard::VERSION
  s.summary     = "Visitor tracking Rails Engine"
  s.authors     = [ "rygiel.net" ]
  s.files       = Dir["{app,config,db,lib}/**/*", "trackguard.gemspec"]
  s.require_paths = [ "lib" ]

  s.add_dependency "rails", ">= 8.1"
end
