module OsuRuby::Database
  module Datatype
    # a simple wrapper for a Psuedo-class system to encode data back and forth.
    # @api private
    # @note Anything shown in here is merely a generated value.
    #   Please consult the source code for what you want to see.
    # @note This class is instantly removed from direct references once finished
    #   instantiation of its subclasses. Only used for references.
    class Converter
      # @!visibility private
      def initialize(name, enc, dec)
        @name    = name
        @encoder = enc
        @decoder = dec
        freeze
      end
      # convert to "STRING"
      def encode(x)
        @encoder.call(x)
      end
      # convert to given data
      def decode(x)
        @decoder.call(x)
      end
      # @!visibility private
      def name; @name; end
      # @!visibility private
      def inspect; "<Class:#{self.name}>"; end
      # @!visibility private
      def to_s; @name; end
      class << self
        # registers the name into the Datatype namespace with both encoding and decoding support
        # @!macro [attach] Converter.create
        #   @!parse class $1 < Converter; encode = $2; decode = $3; end
        # @return [Converter] psuedo-class
        def create(name, enc, dec)
          mod = Module.nesting[-2]
          if mod.const_defined?(name,false) && !(Converter === mod.const_get(name,false)) then
            fail ArgumentError, "Cannot overwrite a non-Converter object"
          end
          cls = new(name, enc, dec)
          mod.const_set(name, cls)
          cls
        end
      end
    end
    # @macro Converter.create
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
    # @macro Converter.create
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
      # splits integral and decimal part
      # @return [(Integer, Integer)] pair of integer
      def split
        sign_flag  = (flags & 0x80000000).zero? ? 0 : -1
        scale_flag = (flags & 0x00ff0000) >> 16
        scale_val  = (10 ** scale_flag)
        num_value  = (((hi << 64) | (med << 32) | low) % (1 << 96)) | sign_flag
        final_val  = num_value / scale_val
        [final_val.to_i, (final_val * scale_val).to_i]
      end
      # Converts the struct into 16-bytes of string.
      # @return [String]
      def to_bytes
        [low, med, hi, flags].pack("L<4")
      end
      # @return [Float]
      def to_f
        to_s.to_f
      end
      # @return [BigDecimal]
      def to_d
        require 'bigdecimal'
        BigDecimal(to_s)
      end
      # @return [Integer]
      def to_i; to_int; end
      # @return [Integer]
      def to_int
        split.first
      end
      # @return [Rational]
      def to_r
        Rational(to_s)
      end
      # @return [String]
      def to_s
        split.join('.')
      end
      class << self
        # reads back the byte format that is created through #to_bytes
        # @param string [String] 16-bytes of string
        # @return [Decimal]
        def read_bytes(string)
          new(*string.unpack('l<'))
        end
        # @overload try_convert(value)
        #   @param value [String] string that need to be split upon.
        # @overload try_convert(value)
        #   @param value [Float, Rational] convert to string of float-form
        # @overload try_convert(value)
        #   @param value [Integer]
        # @raise [ArgumentError] failed convert attempt
        # @return [Decimal]
        def try_convert(value)
          ary = []
          bits = [0, 0, 0]
          case value
          when String
            ary.push *value.split('.')
            ary.map!(&:to_i)
          when Float, Rational
            return try_convert(value.to_f.to_s)
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
