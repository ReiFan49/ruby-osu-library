module OsuRuby::Database
  module Datatype
    class Converter
      def initialize(name, enc, dec)
        @name    = name
        @encoder = enc
        @decoder = dec
        freeze
      end
      def encode(x)
        # convert to "STRING"
        @encoder.call(x)
      end
      def decode(x)
        # convert to given data
        @decoder.call(x)
      end
      def name; @name; end
      def inspect; "<Class:#{self.name}>"; end
      def to_s; @name; end
      class << self
        def create(name, enc, dec)
          cls = new(name, enc, dec)
          Module.nesting[-2].const_set(name, cls)
          cls
        end
      end
    end
    Converter.create('ULEB128', proc { |x|
      bytes = []
      loop do
        bytes << ((x & 0x7f) | (x >= 0x80 ? 0x80 : 0x00))
        x >>= 7
        break if x == 0
      end
      bytes.pack('C*')
    }, proc { |s|
      result = 0
      bits   = 0
      index  = 0
      loop do
        bits    = s[index].ord
        result |= (bits & 0x7f) << (7 * index)
        index  += 1
        break if (bits & 0x80) == 0
        break if index >= s.size
      end
      result
    })
    Converter.create('Time', proc { |t|
      [621355968000000000 + (10000000 * t.to_f).to_i].pack('Q<')
    }, proc { |s|
      ::Time.at(Rational(s.unpack('Q<').first,10000000) - 62135596800)
    })
    Decimal = Struct.new(:low, :med, :hi, :flags)
    class Decimal
      %i(low med hi flags).each do |m|
        define_method m do
          [super()].pack('L<').unpack('l<').first
        end
        define_method :"#{m}=" do |value|
          super([value].pack('L<').unpack('l<').first)
        end
      end
      def split
        sign_flag  = (flags & 0x80000000).zero? ? 0 : -1
        scale_flag = (flags & 0x00ff0000) >> 16
        scale_val  = (10 ** scale_flag)
        num_value  = (((hi << 64) | (med << 32) | low) % (1 << 96)) | sign_flag
        final_val  = num_value / scale_val
        [final_val.to_i, (final_val * scale_val).to_i]
      end
      def to_bytes
        [low, med, hi, flags].pack("L<4")
      end
      def to_f
        to_s.to_f
      end
      def to_d
        BigDecimal.new(to_s)
      end
      def to_i; to_int; end
      def to_int
        split.first
      end
      def to_r
        Rational(to_s)
      end
      def to_s
        split.join('.')
      end
      class << self
        def read_bytes(string)
          new(*string.unpack('l<'))
        end
        def try_convert(value)
          ary = []
          bits = [0, 0, 0]
          case value
          when String
            ary.push *value.split('.')
            ary.map!(&:to_i)
          when Float, Rational
            return try_convert(value.to_s)
          when Integer
            ary.push value
          else
            fail ArgumentError, "unable to convert #{value}"
          end
          ary << 0 if ary.size == 1
          scale_size = ary[1] > 0 ? Math.log10(ary[1]).floor.to_i.succ : 0
          sign_flag  = ary[0] < 0 ? 0x80 : 0x00
          flag_bits  = (sign_flag << 8 | (scale_size & 0xff)) << 16
          comb_val   = (ary[0] + ((ary[1]) * [1, scale_size].min)).to_i
          bits.size.times do |i|
            bits[i] = [comb_val >> (1 << (32 * i))].pack('L<').unpack('l<').first
          end
          new(*bits, flags)
        end
      end
    end
    remove_const :Converter
  end
end
