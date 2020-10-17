require 'minitest/spec'
require 'minitest/autorun'
require 'osu-ruby2'
require 'osu-ruby2/database/file'

# note: use _(expression).expectation_method
describe OsuRuby::Database::OsuDB do
  dbc = OsuRuby::Database
  it 'read 2012 database' do
    db = dbc::OsuDB.new(File.join(__dir__,'osu!.20121227.db'))
    _{
      db.read_file
    }.must_be_silent
  end
end
