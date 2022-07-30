require 'osu-ruby2/parser'
module OsuRuby
  module Beatmap
    '
      about to use "Parser" as well, but namespace hell
      won\'t be fun so nope.
    '
    # parser assistant for beatmaps
    module ParseHelper
      # defines generic comma split entries
      CommaSplitSection = Parser::Section.create(Parser::CommaSplitEntry)
      # No-Parse Comma Splitter
      class CommaSplitRawEntry < Parser::CommaSplitEntry
        private
        def _upcast(val, key=nil)
          val
        end
        def _downcast(val)
          val
        end
      end
      # Timing Point's Comma Splitter
      class TimingPointEntry < Parser::CommaSplitEntry
        private
        # do not upcast if its extension of hitobjects
        def _upcast(val, key=nil)
          if [0, 1].include? key then
            Float(val)
          else
            Integer(val)
          end
        end
        def _downcast(val)
          String(val)
        end
      end
      # Hit Object's Comma Splitter
      class HitObjectEntry < Parser::CommaSplitEntry
        def hit_type
          _raw = _upcast(@args[3], 3)
          _type = 0
          if (_raw & 128).nonzero? then
            _type = 3
          elsif (_raw & 8).nonzero? then
            _type = 2
          elsif (_raw & 2).nonzero? then
            _type = 1
          end
          _type
        end
        private
        # do not upcast if its extension of hitobjects
        def _upcast(val, key=nil)
          if [0, 1, 2, 3, 4].include? key then
            super
          else
            val
          end
        end
        def _downcast(val)
          case val
          # De-quote this.
          when String
            val
          when Rational
            String(val.to_f)
          else
            super
          end
        end
      end
      # defines +TimingPoints+ section parser.
      TimingPointSection = CommaSplitSection.create(TimingPointEntry)
      # defines +HitObject+ section parser.
      HitObjectSection = CommaSplitSection.create(HitObjectEntry)
    end
    # Simple parser that allows Beatmap parsing capability.
    class BasicParser < Parser::RawFile
      # (see Parser::RawFile#parse_header)
      def parse_header(io)
        @version  = io.gets.scan(/\d+/).first.to_i
      end
      # @overload convert
      #   create new object using given parsed structure data.
      #   @return [Beatmap::Data] new beatmap object
      # @overload convert(bm)
      #   @note using this form will overwrite all data on given beatmap object. use this with care.
      #   @param bm [Beatmap::Data] Beatmap object reference
      #   @return [Beatmap::Data] content refreshed beatmap object.
      def convert(bm = nil)
        unless Beatmap::Data === bm then
          bm = Beatmap::Data.new
        end
        bm.clear :internal
        bm.update_sections @sections
        bm
      end
      private
      # Prepends +.osu+ compatible header before compilation.
      # (see Parser::RawFile#compile_contents)
      def compile_contents
        version_header = "osu file format v#{@version}"
        [version_header, super].join($/)
      end
      def determine_sections(name, contents)
        case name
        when 'TimingPoints'
          ParseHelper::CommaSplitSection.new name, contents.join($/)
        when 'HitObjects'
          ParseHelper::HitObjectSection.new name, contents.join($/)
        else
          super
        end
      end
    end
  end
end
