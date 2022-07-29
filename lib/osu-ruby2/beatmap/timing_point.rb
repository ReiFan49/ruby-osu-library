module OsuRuby
  module Beatmap
    module TimingPoints
      # Important methods of TimingPoints classes
      KEY_METHODS = %i(time value measure sample custom volume flags)
      # @abstract Basic representation of Timing Points
      class Base
        include Interface::AbstractClass
        # 395930,800,6,2,0,60,1,0
        # 395930,-175,6,2,0,60,0,0
        self.abstract!
        # position of timingpoint object.
        attr_reader :time
        def initialize(time, value, measure = 4, sample = 1, custom = 0, volume = 70, type = 1, flags = 0)
          super
          @time = time
          @value = value
          @measure = measure
          @sample = sample
          @custom = custom
          @volume = volume
          @type = type
          @flags = flags
        end
        # @!method value
        #   @abstract a raw value of timing section
        #   @return [Float]
        abstract_method :value
        # @!method value=(new_value)
        #   @abstract a raw value of timing section
        #   @param new_value [Numeric] depends on implementation
        #   @return [void]
        abstract_method :value=
        KEY_METHODS.each do |m|
          define_method m do instance_variable_get(:"@#{m}") end unless instance_methods.include?(m)
          define_method :"#{m}=" do |new_value| instance_variable_set(:"@#{m}", new_value) end unless instance_methods.include?(:"#{m}=")
        end
        # checks timing point flag 0th-bit
        # @return [Boolean]
        def is_kiai?; !(@flags & (1<<0)).zero?; end
        # checks timing point flag 3rd-bit
        # @return [Boolean]
        def is_omit_bar?; !(@flags & (1<<3)).zero?; end
        # checks timing point custom sample index usage
        # @return [Boolean]
        def is_custom_sample?; @custom.positive?; end
        def as_osu
          [@time, @value, @measure, @sample, @custom, @volume, @type, @flags]
        end
      end
      class Absolute < Base
        def bpm; Rational(60000, @value).to_f end
        def bpm=(value); @value = Rational(60000, value).to_f end
        alias value bpm
        alias value= bpm=
      end
      class Relative < Base
        def speed; Rational(-100, @value).to_f end
        def speed=(value); @value = Rational(-100, value).to_f end
        alias value speed
        alias value= speed=
      end
      # This is a summarized timing class. Contains both reference to both current active uninherited/absolute
      # and inherited/relative class. All the methods from KEY_METHODS constant are delegated carefully.
      #
      # If the inherited/relative timing existed, it'll take priority over the uninherited/absolute one.
      Compound = Struct.new(:base, :rel) do
        # @return [Float] current BPM of the timing
        def bpm
          base.bpm
        end
        # @return [Float] current speed of the timing, defaults to 1.0 if none.
        def speed
          rel&.speed || 1.0
        end
      end
      Compound.class_exec do
        KEY_METHODS.each do |k|
          define_method k do
            ret = nil
            size.pred.downto(0) do |i|
              break if ret
              next unless self[i].nil?
              ret = self[i].send(k)
            end
            ret
          end
        end
      end
    end
  end
end
