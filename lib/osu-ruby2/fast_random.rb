module OsuRuby
  # Fast PRNG used by osu!
  # @see https://github.com/ppy/osu/raw/4bc26dbb487241e2bbae73751dbe9e93a4e427da/osu.Game/Utils/LegacyRandom.cs
  class FastRandom
    def initialize(seed)
      reset(seed)
    end
    # reset the seeding.
    # @return [void]
    def reset(seed)
      @ul = [
        273326509, seed % (1 << 32),
        842502087, 3579807591, 0
      ]
      @c = 32
    end
    # obtain next 32-bit integer
    # @return [Integer] unsigned integer
    def next_ulong
      ul = (@ul[1] ^ (@ul[1] << 11)) % (1 << 32)
      @ul[1], @ul[2], @ul[3] = @ul[2], @ul[3], @ul[0]
      @ul[0] = @ul[0] ^ (@ul[0] >> 19) ^ (ul ^ (ul >> 8))
    end
    alias next next_ulong
    # obtain value with given range
    # @param a [Integer] low bound
    # @param b [Integer] high bound
    # @return [Float] real number.
    def next_range(a,b)
      ia, ib = [a,b].map do |x| [x].pack('L<').unpack1('l<') end
      sl = [ib - ia].pack('L<').unpack1('l<')
      next_ulong
      a + (sl < 0) ?
        (2.3283064365386963e-10 * @ul[0] * (b - a)) :
        (peek_double * sl)
    end
    # obtain next double
    # @return [Float] real number
    def next_double
      next_ulong
      peek_double
    end
    # obtain random bytes for given string buffer
    # @return [String]
    def next_bytes(string)
      ul = [@ul[1], @ul[2], @ul[3], @ul[0]]
      sl = 0
      while sl < string.length
        next_ulong
        si = [4,string.length - sl].min
        string[sl,si] = [@ul[0]].pack('<L')
        sl += si
      end
      string
    end
    # obtain next boolean
    # @return [Boolean]
    def next_bool
      if(@c == 32)
        @ul[4] = next_ulong
        @c = 1
        @ul[4].odd?
      else
        @c += 1
        (@ul >>= 1).odd?
      end
    end
    private
    def peek_double
      4.6566128730773926e-10 * (@ul[0] & 0x7fffffff)
    end
  end
end
