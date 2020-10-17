require 'forwardable'
module OsuRuby
  Object.instance_exec do
    def to_osu
      if respond_to?(:as_osu) then
        as_osu.compact.join(',')
      else
        fail NotImplementedError, "unsupported to_osu without as_osu"
      end
    end
  end
  module Beatmap
    DifficultyProgress = Struct.new(:low, :mid, :high) do
      def intiialize(*args)
        super
        freeze
      end
      def obtain(value)
        if value >= 5 then
          self.mid + Rational(value - 5, 5 * (self.high - self.mid))
        else
          self.low + Rational(value - 0, 5 * (self.mid  - self.low))
        end
      end
      def approach(value)
        if low <= mid && mid <= high then
          if value >= mid then
            5 + Rational(value - self.mid, self.high - self.mid) * 5
          else
            0 + Rational(value - self.low, self.mid  - self.low) * 5
          end
        elsif high <= mid && mid <= low then
          if value >= mid then
            5 - Rational(value - self.mid, self.low -  self.mid) * 5
          else
            5 + Rational(self.mid - value, self.mid - self.high) * 5
          end
        else
          nil
        end
      end
    end
    Color = Struct.new(:r,:g,:b) do
      def as_osu
        to_a
      end
    end
    class Data
      include Interface::ExtendableMethods
      extend Forwardable
      SPECIAL_SECTIONS   = %i(TimingPoints HitObjects).freeze
      SPINNER_DIFFICULTY = DifficultyProgress.new(3.0,5.0,7.5)
      def initialize
        @sections = {}
        @timings  = []
        @objects  = []
        clear
      end
      def initialize_copy(other)
        super
        transfer_linkage(other)
        clear :copy
      end
      private
      def transfer_linkage(other)
        @timings.map! do |t| t.dup end
        @objects.map! do |o|
          o2 = o.dup
          o2.instance_variable_set(:@beatmap,self)
        end
      end
      public
      def clear(mode = :nil)
        reset_caches
        process_extensions
      end
      def clear_caches
        (@_cache_timing ||= {}).clear
      end
      def spinner_difficulty
        SPINNER_DIFFICULTY.obtain(self.od)
      end
      def quad_tick_rate?
        tr = self.tick_rate
        bt = Math.log2(tr)
        bt == bt.to_i
      end
      def triple_tick_rate?
        tr = self.tick_rate
        bt = Math.log(tr,3)
        bt == bt.to_i
      end
      def strange_tick_rate?
        !(triple_tick_rate? || quad_tick_rate?)
      end
      def timing_at(time)
        @_cache_timing ||= {}
        unless @_cache_timing.key?(time.to_f)
          tplist = timings.group_by do |t| t.type end
          timing_point = tplist[0].take_while do |t|
            t.time <= time
          end.last || tplist[0].first
          relative_point = tplist[1].select do |t|
            t.time >= timing_point.time
          end.take_while do |t|
            t.time <= time
          end.last || nil
          TimingPoints::Compound.new(
            timing_point,
            relative_point
          ).tap do |tp|
            @_cache_timing[time.to_f] = tp
          end
        end
        @_cache_timing[time.to_f]
      end
      def bpm_at(time)
        timing_at(time).bpm
      end
      def sv_at(time)
        base_sv * timing_at(time).speed
      end
      class << self
        def parse(str)
          
        end
      end
    end
    DummyBeatmap = Data.new
    require_relative 'timing_point'
    module HitObjects
      VALID_NOTETYPE = 1 | 2 | 8 | 128
      class Base
        include Interface::ExtendableMethods
        include Interface::AbstractClass
        attr_reader :x, :y, :start_time, :type, :hitsound
        def initialize(beatmap, pos_x, pos_y, start_time, note_type, hitsounds, *extras)
          super
          @beatmap = beatmap
          @x, @y, @start_time, @hitsounds = pos_x, pos_y, start_time, hitsounds
          @type = note_type & VALID_NOTETYPE
          @combo_new = !(note_type & 4).zero?
          @combo_offset = @combo_new ? (note_type >> 4) & 7 : 0
          process_extras(*extras)
          process_extensions
        end
        def end_time
          start_time
        end
        def length; end_time - start_time; end
        def note_type
          @type | (@combo_new ? (4 | (@combo_offset << 4)) : 0)
        end
        def extra_data
          @extras
        end
        def timing_data
          @timing_data ||= @beatmap.timing_at(start_time)
        end
        def is_new_combo?; @combo_new; end
        def is_combo_hax;  @combo_offset > 0; end
        def no_hitsound?; @hitsounds.zero?; end
        def have_hitsound?; !no_hitsound?; end
        def have_base?;
          $stderr.puts "You are not supposed to call this. Hitnormal is a special entity that usually tied along with other hitsounds."
          true
        end
        def have_whistle?; (@hitsounds & 2).zero? end
        def have_finish?; (@hitsounds & 4).zero? end
        def have_clap?; (@hitsounds & 8).zero? end
        def process_extras(*extras)
          @extras = nil
        end
        def as_osu
          [@x.to_i, @y.to_i, @start_time.to_i, note_type, @hitsound]
        end
        def to_osu
          as_osu.compact.join(',')
        end
        class << self
          def parse(beatmap,str)
            args = str.split(',')
            5.times do |i| args[i] = Integer(args[i],10) end
            unless self.notetype.nil? then
              notetype = args[3] & VALID_NOTETYPE
              unless self.notetype == notetype
                fail TypeError, "Misparsed notetype of #{notetype} into #{self.name}"
              end
            end
            new(beatmap,*args)
          end
          private
          def notetype; @notetype; end
          def notetype=(value); @notetype = value; end
        end
        self.abstract!
      end
      class BaseHitsoundModifier
        
      end
      class SliderHitsoundModifier
      end
      class Circle < Base
        self.notetype = 1
      end
      class Slider < Base
        self.notetype = 2
        def end_time
          start_time + Rational(@slider.length * @slider.repeat,100 * @beatmap.sv_at(start_timing)).to_i
        end
        def tick_rate
          @beatmap.tick_rate
        end
        def tick_count
          Rational(self.length * self.tick_rate,@beatmap.bpm_at(start_time)).floor - repeat_count
        end
      end
      class Spinner < Base
        self.notetype = 8
        def process_extras(end_time, *extras)
          @end_time = end_time
        end
        attr_reader :end_time
        def spin_counter
          self.class.simulate_spin(end_time - start_time, od: @beatmap.od)
        end
        def spin_complete
          spin_counter
        end
        def self.simulate_spin(duration, od: 5)
          (Rational(duration, 1000) * Data::SPINNER_DIFFICULTY.obtain(od)).to_i
        end
      end
      class Drumroll < Slider
        def initialize(*args)
          @tick_rate = nil
        end
        def tick_rate
          return @tick_rate unless @tick_rate.nil?
          beat_len = Rational(60000,(@beatmap.triple_tick_rate? ? 6 : 8) * @beatmap.bpm_at(start_time))
          if beat_len < 60
            bpm_level = Math.log2(beat_len/60.0).floor
          elsif beat_len > 120
            bpm_level = Math.log2(beat_len/60.0).ceil - 1
          else
            bpm_level = 0
          end
          bpm_modifier = 2.0 ** (-bpm_level)
          @tick_rate    = beat_len * bpm_modifier
        end
        def tick_count
          Rational(self.length * self.tick_rate,@beatmap.bpm_at(start_time)).round + 1
        end
      end
      class Denden < Spinner
        def self.simulate_spin(duration, od: 5)
          [super(duration, od: od) * 1.65,1].max.to_i.succ
        end
      end
      class BananaRain < Spinner
        def spin_counter
          (self.length / self.banana_delay).floor + 1
        end
        def spin_complete
          0
        end
        def banana_delay
          len = length
          len /= 2 while len > 100.0
          len
        end
      end
      class Hold < Base
      end
      class << self
        def determine(beatmap, str)
          args = str.split(',')
          5.times do |i| args[i] = Integer(args[i],10) end
          type = args[3] & VALID_NOTETYPE
          
          note_class.parse(beatmap,str)
        end
      end
    end
  end
end
