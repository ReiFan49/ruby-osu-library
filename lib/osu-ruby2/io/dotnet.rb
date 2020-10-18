require 'osu-ruby2/database/datatype'
require 'osu-ruby2/interface'
module OsuRuby
  module IO
    # osu! dotNET read utility
    module AdvancedRead
      private
      def _confirm_peek(n=1)
        fail ArgumentError, "expected to read byte(s)" if n < 0
        return ''.b if n == 0
        s = pos
        b = read(n)
        if b.size != n then
          self.pos = s
          fail EOFError, "Not enough bytes received. (#{b.size} instead of #{n})"
        else
          b
        end
      end
      public
      # @return [String] characters
      def read_char(n=1)
        _confirm_peek(n)
      end
      # @return [Boolean] boolean
      def read_boolean
        !_confirm_peek(1).ord.zero?
      end
      # @!method read_byte
      #   @return [Integer] unsigned integer 8-bit
      # @!method read_short
      #   @return [Integer] unsigned integer 16-bit
      # @!method read_long
      #   @return [Integer] unsigned integer 32-bit
      # @!method read_long64
      #   @return [Integer] unsigned integer 64-bit
      # @!method read_signed_byte
      #   @return [Integer] signed integer 8-bit
      # @!method read_signed_short
      #   @return [Integer] signed integer 16-bit
      # @!method read_signed_long
      #   @return [Integer] signed integer 32-bit
      # @!method read_signed_long64
      #   @return [Integer] signed integer 64-bit
      [[:byte,"C"],[:short,"S"],[:long,'L'],[:long64,'Q']].each_with_index do |(c,f),i|
        [false,true].each_with_index do |s,j|
          name = [:read,s ? 'signed' : nil,c].compact.join('_')
          byte = 1 << i
          n = 1
          define_method name do
            ret = _confirm_peek(byte).unpack(sprintf("%s%s%d",s ? f.downcase : f,i.nonzero? ? '<' : '',n))
            ret.size == 1 ? ret.first : ret
          end
          define_method :"read_#{s ? 's' : 'u'}#{byte << 3}" do
            send(name)
          end
          define_method :"read_#{s ? 'int' : 'uint'}#{byte << 3}" do
            send(name)
          end
        end
      end
      # @!method read_single
      #   @return [Float] Single-Precision Float
      # @!method read_double
      #   @return [Float] Double-Precision Float
      [[:single,'e'],[:double,'E']].each_with_index do |(c,f),i|
        n = 1
        byte = 4 << i
        define_method "read_#{c}" do
          ret = _confirm_peek(byte).unpack(
            sprintf("%s%d",f,n)
          )
          ret.size == 1 ? ret.first : ret
        end
      end
      # @return [Integer] Unsigned Little Endian Bit 128
      def read_uleb128
        b = ""
        loop do
          c = read_byte
          b << c
          break if (c & 0x80).zero?
        end
        Database::Datatype::ULEB128.decode(b)
      end
      # @return [String] osu! DB String Format
      def read_dotnet_osu_string
        conf_flag = read_byte
        case conf_flag
        when 0; return nil
        end
        size = read_uleb128
        read_char(size).force_encoding('utf-8')
      end
      # @return [Database::Datatype::Decimal] .NET decimal
      def read_dotnet_decimal
        Database::Datatype::Decimal.read_bytes(*Array.new(4) { read_long })
      end
      # @return [Time] Date object based on .NET ticks
      def read_dotnet_time
        Database::Datatype::Time.decode(read_char(8))
      end
      # @raise [NotImplementedError]
      def read_dotnet_serializer
        fail NotImplementedError
      end
      # @return [String] characters
      def read_char_array
        read_char(read_signed_long)
      end
      # @return [Array<Integer>] bytes
      def read_byte_array
        size = read_signed_long
        _confirm_peek(size).unpack("C#{size}")
      end
      # @return [Boolean,Integer,String,Float,Database::Datatype::Decimal,Time,Array<Integer>,Object] depends on first byte
      def read_osu_type
        case read_byte
        when  1; read_boolean
        when  2; read_byte
        when  3; read_short
        when  4; read_long
        when  5; read_long64
        when  6; read_signed_byte
        when  7; read_signed_short
        when  8; read_signed_long
        when  9; read_signed_long64
        when 10; read_char
        when 11; read_dotnet_osu_string
        when 12; read_single
        when 13; read_double
        when 14; read_dotnet_decimal
        when 15; read_dotnet_time
        when 16; read_byte_array
        when 17; read_char_array
        when 18; read_dotnet_serializer
        else; nil
        end
      end
    end
    # osu! dotNET write utility
    module AdvancedWrite
      # @return [void]
      def write_null(*)
        write(0.chr)
      end
      # @param c [String]
      # @return [void]
      def write_char(c)
        write(c)
      end
      # @param bool [Boolean]
      # @return [void]
      def write_boolean(bool)
        write((bool ? 1 : 0).chr)
      end
      # @!method write_byte(num)
      #   @param num [Integer] unsigned integer 8-bit
      #   @return [void]
      # @!method write_short(num)
      #   @param num [Integer] unsigned integer 16-bit
      #   @return [void]
      # @!method write_long(num)
      #   @param num [Integer] unsigned integer 32-bit
      #   @return [void]
      # @!method write_long64(num)
      #   @param num [Integer] unsigned integer 64-bit
      #   @return [void]
      # @!method write_signed_byte(num)
      #   @param num [Integer] signed integer 8-bit
      #   @return [void]
      # @!method write_signed_short(num)
      #   @param num [Integer] signed integer 16-bit
      #   @return [void]
      # @!method write_signed_long(num)
      #   @param num [Integer] signed integer 32-bit
      #   @return [void]
      # @!method write_signed_long64(num)
      #   @param num [Integer] signed integer 64-bit
      #   @return [void]
      [[:byte,"C"],[:short,"S"],[:long,'L'],[:long64,'Q']].each_with_index do |(c,f),i|
        [false,true].each_with_index do |s,j|
          name = [:write,s ? 'signed' : nil,c].compact.join('_')
          byte = 1 << i
          n = 1
          define_method name do |num|
            write([num].pack(sprintf("%s%s%d",s ? f.downcase : f,i > 0 ? '<' : '',n)))
          end
          define_method :"write_#{s ? 's' : 'u'}#{byte << 3}" do |num|
            send(name, num)
          end
          define_method :"write_#{s ? 'int' : 'uint'}#{byte << 3}" do |num|
            send(name, num)
          end
        end
      end
      # @!method write_single(num)
      #   @param num [Float] Single Precision Float
      #   @return [void]
      # @!method write_double(num)
      #   @param num [Float] Double Precision Float
      #   @return [void]
      [[:single,'e'],[:double,'E']].each_with_index do |(c,f),i|
        n = 1
        byte = 4 << i
        define_method "write_#{c}" do |num|
          write([num].pack(sprintf("%s%d",f,n)))
        end
      end
      # @param num [Integer] ULEB range string
      # @return [void]
      def write_uleb128(num)
        write(Database::Datatype::ULEB128.encode(num))
      end
      # @param str [String]
      # @return [void]
      def write_dotnet_osu_string(str)
        if str.nil? then
          write_null(str)
          return
        end
        write(11.chr)
        write_uleb128(str.bytes.size)
        write(str.b)
      end
      # @param dec [Database::Datatype::Decimal] dotNET decimal
      # @return [void]
      def write_dotnet_decimal(dec)
        write(dec.to_bytes)
      end
      # @param time [Time]
      # @return [void]
      def write_dotnet_time(time)
        write(Database::Datatype::Time.encode(time))
      end
      # @raise [NotImplementedError]
      def write_dotnet_serializer(obj)
        fail NotImplementedError
      end
      # @param ary [String] array of char
      # @return [void]
      def write_char_array(ary)
        write_signed_long(ary.size)
        write(ary)
      end
      # @param ary [Array<Integer>] array of bytes
      # @return [void]
      def write_byte_array(ary)
        write_signed_long(ary.size)
        write(ary.pack('C*'))
      end
      # @param type [Integer] denotes the variadic type index
      # @param content [Boolean,Integer,String,Float,Database::Datatype::Decimal,Time,Array<Integer>,Object] denotes what method to parse the object
      # @return [void]
      # @see #write_expect
      def write_osu_type(type, content)
        write_expect(type, content)
      end
      # Writes a variadic-type supported osu! variable bytes.
      # @param codes [<Integer, Object>] a flat-tuple of Integer-Object pair.
      # @example One-Pair
      #   write_expect(1,false)
      # @example Two-Pair
      #   write_expect(2,0x7f,3,0x7fff)
      # @example Four-Pair
      #   write_expect(4,0x7fff_ffff,5,0x7fff_ffff_ffff_ffff,6,-128,7,-32768)
      # @return [void]
      def write_expect(*codes)
        fail ArgumentError, "requires at least 1 argument" if codes.empty?
        codes.each_slice(2) do |(code, obj)|
          action = case code
                   when  0; :write_null
                   when  1; :write_boolean
                   when  2; :write_byte
                   when  3; :write_short
                   when  4; :write_long
                   when  5; :write_long64
                   when  6; :write_signed_byte
                   when  7; :write_signed_short
                   when  8; :write_signed_long
                   when  9; :write_signed_long64
                   when 10; :write_char
                   when 11; :write_dotnet_osu_string
                   when 12; :write_single
                   when 13; :write_double
                   when 14; :write_dotnet_decimal
                   when 15; :write_dotnet_time
                   when 16; :write_byte_array
                   when 17; :write_char_array
                   else; nil
                   end
          if action == :write_null then
            write_null
          elsif action then
            write_byte(code)
            public_send(action, obj)
          else
            write_byte(18)
            write_dotnet_serializer(obj)
          end
        end
      end
    end
    # Wrapper for Ruby-IO to perform some osu!-related dotnet operations.
    class DotNetIO
      include AdvancedRead
      include AdvancedWrite
      def initialize(io)
        base_cls = method(__method__).owner
        fail TypeError, "Expects a non-#{base_cls.name}" if base_cls === io.class
        @io = io
      end
      # Please refer to IO that passed into this instance.
      def method_missing(meth, *args, &block)
        priv = false
        return @io.send(meth, *args, &block) if @io.respond_to?(meth, priv)
        super
      end
    end
  end
end
