require 'osu-ruby2'
module OsuRuby
  # @!visiblity private
  # @note Make sure that this extension only loaded when the YARD module is loaded.
  module YARDExt
  end
  require_ns
end if defined?(YARD)
