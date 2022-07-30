module OsuRuby
  # require 'osu-ruby2'
  
  # @api private
  # @!visibility private
  # @note Make sure that this extension only loaded when the YARD module is loaded.
  module YARDExt
  end
  
  Dir.chdir(__dir__) do
    Dir.glob('yard_ext/**/*.rb') do |fn| require_relative fn end
  end
end if defined?(YARD)
