require 'osu-ruby2/database/datatype'
require 'osu-ruby2/interface'
module OsuRuby
  module IO
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
      def read_char(n=1)
        _confirm_peek(n)
      end
      def read_boolean
        !_confirm_peek(1).ord.zero?
      end
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
      def read_uleb128
        b = ""
        loop do
          c = read_byte
          b << c
          break if (c & 0x80).zero?
        end
        Database::Datatype::ULEB128.decode(b)
      end
      def read_dotnet_osu_string
        conf_flag = read_byte
        case conf_flag
        when 0; return nil
        end
        size = read_uleb128
        read_char(size).force_encoding('utf-8')
      end
      def read_dotnet_decimal
        Database::Datatype::Decimal.read_bytes(*Array.new(4) { read_long })
      end
      def read_dotnet_time
        Database::Datatype::Time.decode(read_char(8))
      end
      def read_dotnet_serializer
        fail NotImplementedError
      end
      def read_char_array
        read_char(read_signed_long)
      end
      def read_byte_array
        size = read_signed_long
        _confirm_peek(size).unpack("C#{size}")
      end
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
    module AdvancedWrite
      def write_null(*)
        write(0.chr)
      end
      def write_char(c)
        write(c)
      end
      def write_boolean(bool)
        write((bool ? 1 : 0).chr)
      end
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
      [[:single,'e'],[:double,'E']].each_with_index do |(c,f),i|
        n = 1
        byte = 4 << i
        define_method "write_#{c}" do |num|
          write([num].pack(sprintf("%s%d",f,n)))
        end
      end
      def write_uleb128(num)
        write(Database::Datatype::ULEB128.encode(num))
      end
      def write_dotnet_osu_string(str)
        if str.nil? then
          write_null(str)
          return
        end
        write(11.chr)
        write_uleb128(str.bytes.size)
        write(str.b)
      end
      def write_dotnet_decimal(dec)
        write(dec.to_bytes)
      end
      def write_dotnet_time(time)
        write(Database::Datatype::Time.encode(time))
      end
      def write_dotnet_serializer(obj)
        fail NotImplementedError
      end
      def write_char_array(ary)
        write_signed_long(ary.size)
        write(ary)
      end
      def write_byte_array(ary)
        write_signed_long(ary.size)
        write(ary.pack('C*'))
      end
      def write_osu_type(type, content)
        write_expect(type, content)
      end
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
    class DotNetIO
      include AdvancedRead
      include AdvancedWrite
      def initialize(io)
        base_cls = method(__method__).owner
        fail TypeError, "Expects a non-#{base_cls.name}" if base_cls === io.class
        @io = io
      end
      def method_missing(meth, *args, &block)
        priv = false
        return @io.send(meth, *args, &block) if @io.respond_to?(meth, priv)
        super
      end
    end
  end
end
