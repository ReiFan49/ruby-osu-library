module OsuRuby
  module Beatmap
    module TimingPoints
      KEY_METHODS = %i(time value measure sample custom volume flags)
      class Base
        extend Interface::AbstractClass
        self.abstract!
        # 395930,800,6,2,0,60,1,0
        # 395930,-175,6,2,0,60,0,0
        attr_reader :time
        def initialize(time, value, measure = 4, sample = 1, custom = 0, volume = 70, type = 1, flags = 0)
          super
          @time = time
          @value = value
        end
        abstract_method :value
      end
      class Absolute
        def bpm; Rational(60000, @value).to_f end
        def bpm=(value); @value = Rational(60000, value).to_f end
        alias value bpm
        alias value= bpm=
      end
      class Relative
        def speed; Rational(-100, @value).to_f end
        def speed=(value); @value = Rational(-100, value).to_f end
        alias value speed
        alias value= speed=
      end
      Compound = Struct.new(:base, :rel) do
        def bpm
          base.bpm
        end
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
