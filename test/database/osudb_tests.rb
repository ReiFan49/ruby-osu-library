require 'minitest/spec'
require 'minitest/autorun'
require 'osu-ruby2'
require 'osu-ruby2/database/file'

# note: use _(expression).expectation_method
describe OsuRuby::Database::OsuDB do
  dbc = OsuRuby::Database
  it 'reads 2012 database' do
    fn = File.join(__dir__,'osu!.20121227.db')
    skip "File not existed" unless File.exists?(fn)
    db = dbc::OsuDB.new(fn)
    eof = db.read_file
    _(eof).must_equal true
    _(db.version).wont_equal 0
  end
  it 'reads 2020 database' do
    fn = File.join(__dir__,'osu!.20201008.db')
    skip "File not existed" unless File.exists?(fn)
    db = dbc::OsuDB.new(fn)
    eof = db.read_file
    _(eof).must_equal true
    _(db.version).wont_equal 0
  end
  it 'writes 2012 database' do
    fn = File.join(__dir__,'osu!.20121227.db')
    skip "File not existed" unless File.exists?(fn)
    db = dbc::OsuDB.new(fn)
    db.read_file
    new_fn = File.join(__dir__,'ruby.osu!.20121227.db')
    db.write_to_file(new_fn)
    _(File.size(fn)).must_equal File.size(new_fn)
  ensure
    File.unlink(new_fn) rescue 0
  end
  it 'writes migrated 2012 database' do
    fn = File.join(__dir__,'osu!.20121227.db')
    skip "File not existed" unless File.exists?(fn)
    db = dbc::OsuDB.new(fn)
    db.read_file
    new_fn = File.join(__dir__,'ruby.osu!.'+String(OsuRuby::GAME_VERSION)+'.db')
    db.version!
    db.write_to_file(new_fn)
    _(File.exists?(new_fn)).must_equal true
  ensure
    File.unlink(new_fn) rescue 0
  end
end
