(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__).tap do |file|
  File.expand_path("../lib", file).tap do |here| $:.push here unless $:.include?(here) end
end

require 'osu-ruby2/version'

Gem::Specification.new do |s|
  s.name        = "osu-ruby2"
  s.version     = OsuRuby::GEM_VERSION
  s.authors     = ["Rei Hakurei"]
  s.email       = ["reimu_after_marisa@yahoo.com"]
  s.homepage    = "https://bloom-juery.net"
  s.summary     = "ruby osu! library"
  s.description = ""
  s.license     = "MIT"

  s.require_paths = %w(lib)
  s.files = Dir["lib/**/*.rb", "bin/*", "MIT-LICENSE", "Rakefile", "*.md"]
end
