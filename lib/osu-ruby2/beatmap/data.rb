require 'forwardable'
# Let all Object able to implement as_osu typing.
Object.instance_exec do
  def to_osu
    if respond_to?(:as_osu) then
      as_osu.compact.join(',')
    else
      fail NotImplementedError, "unsupported to_osu without as_osu"
    end
  end
end
module OsuRuby
  module Beatmap
    # Three-pair tuple that is used for most of osu! difficulty related scaling.
    DifficultyProgress = Struct.new(:low, :mid, :high) do
      # create immutable tuple.
      def intiialize(*args)
        super
        freeze
      end
      # @!visibility private
      def initialize_dup(other)
        super
        freeze
      end
      # retrieve the +difficulty_value+ on given +value+ (expected from 0 to 10, may go beyond limits)
      # @param value [Numeric] reference value to compare.
      # @return [Numeric] projected +difficulty_value+.
      # @see #approach to compare returned +difficulty_value+ with.
      def obtain(value)
        if value >= 5 then
          self.mid + Rational(value - 5, 5 * (self.high - self.mid))
        else
          self.low + Rational(value - 0, 5 * (self.mid  - self.low))
        end
      end
      # retrieve the +original_value+ on given +difficulty_value+
      # @param value [Numeric] reference value to compare with {#low}, {#mid}, and {#high}.
      # @return [Numeric] projected +priginal_value+ from given +difficulty_value+
      # @see #obtain to compare returned +original_value+ with.
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
    # Defines simple color tuple (non-alpha).
    # @note may mobed to General along with skinning support etc.
    Color = Struct.new(:r,:g,:b) do
      # @return [Array]
      def as_osu
        to_a
      end
    end
    # Represents Beatmap data in general.
    class Data
      include Interface::ExtendableMethod
      extend Forwardable
      # TODO: define special section for parsing etc.
      SPECIAL_SECTIONS    = %i(TimingPoints HitObjects).freeze
      # defines global spinner difficulty used through all main modes.
      SPINNER_DIFFICULTY  = DifficultyProgress.new(3.0,5.0,7.5)
      # osu! beatmap latest version
      LATEST_FILE_VERSION = 14
      
      def initialize
        @version  = LATEST_FILE_VERSION
        @sections = {}
        @timings  = []
        @objects  = []
        clear
      end
      # copies all soft references of the original beatmap to current beatmap.
      # pretty useful for handling converts or mods.
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
          o2.instance_variable_set :@beatmap, self
        end
      end
      # wipe beatmap internal data.
      # @return [void]
      def clear_contents
        @sections.clear
        @timings.clear
        @objects.clear
      end
      public
      def update_contents(parser_data)
      end
      # reset beatmap cache and process the extensions defined
      # @param mode [Symbol, nil] TBD
      # @return [void]
      def clear(mode = nil)
        if %i(internal).include? mode then
          clear_contents
        end
        clear_caches
        unless %i(internal).include? mode then
          process_extensions
        end
      end
      # Clear existing caches stored in a beatmap. Currently it supports following operations:
      #
      # * Clears cached timing from current beatmap.
      #
      # @return [void]
      def clear_caches
        (@_cache_timing ||= {}).clear
      end
      # @return [Float] obtain current beatmap spinner difficulty.
      def spinner_difficulty
        SPINNER_DIFFICULTY.obtain(self.od)
      end
      # @return [Boolean] checks whether the beatmap have +2 x 2^n+ tick rate.
      def quad_tick_rate?
        tr = self.tick_rate
        bt = Math.log2 tr
        bt == bt.to_i
      end
      # @return [Boolean] checks whether the beatmap have +3 x 2^n+ tick rate.
      def triple_tick_rate?
        tr = self.tick_rate
        bt = Math.log tr, 3
        bt == bt.to_i
      end
      # @return [Boolean] checks whether does not use the standard supported tick rate.
      # @see #strange_tick_rate?
      def unusual_tick_rate?
        [0.5, 1.0, 2.0, 3.0, 4.0].all? do |tick|
          tick != self.tick_rate
        end
      end
      # @return [Boolean] checks whether does not satisfy the usual tick rate divisor.
      # @see #unusual_tick_rate?
      def strange_tick_rate?
        !(triple_tick_rate? || quad_tick_rate?)
      end
      # obtain timing point property at given +time+
      # @note This behavior changed in +b20210823.cuttingedge+ build.
      # @todo Different behavior checks will be implemented later.
      # @param time [Numeric, Float] time position to check with.
      # @return [TimingPoints::Compound]
      # @see #bpm_at obtain current BPM
      # @see #sv_at obtain current relative speed
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
            relative_point,
          ).tap do |tp|
            @_cache_timing[time.to_f] = tp
          end
        end
        @_cache_timing[time.to_f]
      end
      # @param time [Float] position to check
      # @return [Float] current BPM at given time position
      # @see #timing_at obtain current timing data.
      # @see #sv_at obtain current relative speed
      def bpm_at(time)
        timing_at(time).bpm
      end
      # @param time [Float] position to check
      # @return [Float] current Slider Velocity at given time position
      # @see #timing_at obtain current timing data.
      # @see #bpm_at obtain current BPM
      def sv_at(time)
        base_sv * timing_at(time).speed
      end
      class << self
        def parse(str)
          
        end
      end
    end
    # defines an empty beatmap. can be used for null beatmap comparison.
    DummyBeatmap = Data.new
    require_relative 'timing_point'
    module HitObjects
      # Valid type flags
      VALID_NOTETYPE = 1 | 2 | 8 | 128
      # @abstract A base class for hitobject-related queries
      # Note that this implement a very core of the object itself.
      # If you want to do a note specific, please see the implementation of subclasses
      class Base
        include Interface::ExtendableMethod
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
        # @return [Integer] hitobject endpoint
        def end_time
          start_time
        end
        # @return [Integer] hitobject duration
        def length; end_time - start_time; end
        # @return [Integer] hitobject raw type
        def note_type
          @type | (@combo_new ? (4 | (@combo_offset << 4)) : 0)
        end
        # @note Not really useful? Hope this is just raw data of extra parameters.
        #   but will see the later implementation after all of them are done.
        # @return [Object, nil] extra data.
        def extra_data
          @extras
        end
        # @return [TimingPoints::Compound] current state of timing point on given object time
        def timing_data
          @timing_data ||= @beatmap.timing_at(start_time)
        end
        # @return [Boolean] new combo marker
        def is_new_combo?; @combo_new; end
        # @return [Boolean] combo hax offset check
        def is_combo_hax;  @combo_offset > 0; end
        # @return [Boolean] no hitsound
        def no_hitsound?; @hitsounds.zero?; end
        # @return [Boolean] have hitsound
        def have_hitsound?; !no_hitsound?; end
        # @return [Boolean] have hitnormal
        def have_base?;
          $stderr.puts "You are not supposed to call this. Hitnormal is a special entity that usually tied along with other hitsounds."
          true
        end
        # @return [Boolean] have hitwhistle
        def have_whistle?; (@hitsounds & 2).zero? end
        # @return [Boolean] have hitfinish
        def have_finish?; (@hitsounds & 4).zero? end
        # @return [Boolean] have hitclap
        def have_clap?; (@hitsounds & 8).zero? end
        # @abstract This function is meant to control any non-base related parsing
        # Including the badly formatted extras from v10
        # @return [void]
        def process_extras(*extras)
          @extras = nil
        end
        # @note It's suggested to use this when trying to convert hitobjects or whatever you think it is.
        #   into a comma-split entry.
        # @return [Array] a modifiable pre-HitObject compliant format data
        # @see #to_osu
        def as_osu
          [@x.to_i, @y.to_i, @start_time.to_i, note_type, @hitsound]
        end
        # @return [String] a HitObject format compliant
        # @see #as_osu
        def to_osu
          as_osu.compact.join(',')
        end
        class << self
          # parses the given string into a HitObject Base.
          # @param beatmap [Beatmap::Data] a beatmap to stick on with.
          # @param str [String] hitobject string to parse on
          # @return [HitObjects::Base]
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
      class BaseCircle < Base
        self.notetype = 1
      end
      class BaseSlider < Base
        self.notetype = 2
        # @return [Integer]
        def end_time
          start_time + Rational(@slider.length * @slider.repeat,100 * @beatmap.sv_at(start_timing)).to_i
        end
        # @return [Integer]
        def tick_rate
          @beatmap.tick_rate
        end
        # @return [Integer]
        def tick_count
          Rational(self.length * self.tick_rate,@beatmap.bpm_at(start_time)).floor - repeat_count
        end
      end
      class BaseSpinner < Base
        self.notetype = 8
        # @return [void]
        def process_extras(end_time, *extras)
          @end_time = end_time
          super(*extras)
        end
        attr_reader :end_time
        # @return [Integer]
        def spin_counter
          self.class.simulate_spin(end_time - start_time, od: @beatmap.od)
        end
        # @return [Integer]
        def spin_complete
          spin_counter
        end
        # @return [Integer]
        def self.simulate_spin(duration, od: 5)
          (Rational(duration, 1000) * Data::SPINNER_DIFFICULTY.obtain(od)).to_i
        end
      end
      class Circle < BaseCircle
      end
      class Slider < BaseSlider
      end
      class Spinner < BaseSpinner
      end
      class Drumroll < BaseSlider
        # @return [void]
        def process_extras(*args)
          super
          @tick_rate = nil
        end
        # @return [Integer] represents drumroll tickrate
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
        # @return [Integer] represents total tick rate inside
        def tick_count
          Rational(self.length * self.tick_rate,@beatmap.bpm_at(start_time)).round + 1
        end
      end
      class Denden < BaseSpinner
        # @return [Integer]
        def self.simulate_spin(duration, od: 5)
          [super(duration, od: od) * 1.65,1].max.to_i.succ
        end
      end
      class BananaRain < BaseSpinner
        # @return [Integer]
        def spin_counter
          (self.length / self.banana_delay).floor + 1
        end
        # @return [Integer] zero.
        def spin_complete
          0
        end
        # @return [Numeric]
        def banana_delay
          len = length
          len /= 2 while len > 100.0
          len
        end
      end
      class Hold < Base
      end
      class << self
        # @return [Base] anything that valid as the subcvlass says...
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
