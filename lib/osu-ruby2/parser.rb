require 'osu-ruby2/interface'
module OsuRuby
  # Personal note of parser classes:
  #
  # Entry classes are supposed to be the basics of parsing osu!-related files.
  # Section classes are meant to use a parser for it's whole section.
  #
  # @see OsuRuby::IO Raw binary IO processor
  # @see OsuRuby::Database::BaseDB osu! binary read support
  module Parser
  end
  require_ns
end
