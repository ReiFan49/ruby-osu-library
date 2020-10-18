require 'minitest/spec'
require 'minitest/autorun'
require 'osu-ruby2'
require 'osu-ruby2/database/file'

# note: use _(expression).expectation_method
describe OsuRuby::Database::OsuDB do
  dbc = OsuRuby::Database
  it 'reads 2012 database' do
    db = dbc::OsuDB.new(File.join(__dir__,'osu!.20121227.db'))
    eof = db.read_file
    _(eof).must_equal true
    _(db.version).wont_equal 0
  end
  it 'writes 2012 database' do
    fn = File.join(__dir__,'osu!.20121227.db')
    db = dbc::OsuDB.new(fn)
    db.read_file
    new_fn = File.join(__dir__,'ruby.osu!.20121227.db')
    db.write_to_file(new_fn)
    _(File.size(fn)).must_equal File.size(new_fn)
    File.unlink(new_fn)
  end
  it 'writes migrated 2012 database' do
    fn = File.join(__dir__,'osu!.20121227.db')
    db = dbc::OsuDB.new(fn)
    db.read_file
    new_fn = File.join(__dir__,'ruby.osu!.'+String(OsuRuby::GAME_VERSION)+'.db')
    db.version!
    db.write_to_file(new_fn)
    _(File.exists?(new_fn)).must_equal true
    File.unlink(new_fn)
  end
end
