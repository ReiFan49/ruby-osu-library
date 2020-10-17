require 'minitest/spec'
require 'minitest/autorun'
require 'osu-ruby2'
require 'osu-ruby2/database'

describe OsuRuby::Database::Datatype do
  d = OsuRuby::Database::Datatype
  describe 'ULEB128' do
    c = d::ULEB128
    [0,8,16,32,48,64,80,96,112].each_cons(2).each_with_index do |(m,n),i|
      it "encodes and decodes integer properly - part #{i.succ}" do
        x = rand((1 << m)..(1 << n))
        r = c.encode(x)
        _(r).must_be_instance_of String
        _(c.decode(r)).must_equal x
        puts "#{x} -> #{r.bytes.map do |x| "%02x"%[x] end.join(' ')}"
      end
    end
  end
end
