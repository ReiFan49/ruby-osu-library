(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__).tap do |file|
  if file.start_with?(File.join(Gem.dir,'specifications')) then
    require 'osu-ruby2/version'
  else
    # No gemfile for local symlink trick
    lib = File.expand_path("../lib", file)
    lib.tap do |here| $:.push here unless $:.include?(here) end
    ver_file = File.join(lib, 'osu-ruby2', 'version.rb')
    eval(File.read(ver_file),nil,ver_file,__LINE__+1)
    $" << ver_file
  end
end unless defined?(OsuRuby::GEM_VERSION)

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
  s.files = Dir["lib/**/*.rb", "MIT-LICENSE", "Rakefile", "*.md"]
  
  s.add_development_dependency 'rubocop', '~> 1.17'
  s.add_dependency 'ruby-xz', '>= 1'
end
