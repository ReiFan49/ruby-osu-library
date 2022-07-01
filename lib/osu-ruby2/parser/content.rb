module OsuRuby
  module Parser
    module ParserContent
      class EntryGroup
        def initialize(*cls)
          @groups = []
          set_classes *cls
        end
        def classes
          @groups
        end
        def classes=(cls)
          set_classes *cls
        end
        def set_classes(*cls)
          cls.select! do |c| c < Entry && c != RawEntry end
          @groups.replace cls
        end
        def determine(str)
          catch :entry_loop do
            @groups.each do |c|
              throw :entry_loop, c if c.condition(str)
            end
            throw :entry_loop, RawEntry
          end.new(str)
        end
      end
      class Entry
        def initialize(*)
          fail TypeError, "Abstract class" if self.class.abstract?
        end
        def comment?
          false
        end
        class << self
          def abstract?
            true
          end
          def condition(str)
            nil
          end
          def inherit(cls)
            cls.class_exec do
              def abstract?
                false
              end
              def determine(str)
                new(str)
              end
              def register_checker(cls)
                Entry.register_checker(cls)
              end
            end
          end
          def register_checker(cls)
            @_class_map ||= []
            @_class_map << cls
            true
          end
          def determine(str)
            @_class_map.find do |cls|
              cls.condition(str)
            end.tap do |entry|
              if entry.nil? then
                RawEntry.determine(str)
              else
                entry.determine(str)
              end
            end
          end
        end
      end
      class RawEntry < Entry
        attr_accessor :content
        def initialize(str)
          @content = str
        end
        def to_s
          @content
        end
        def self.condition(str)
          true
        end
      end
      class CommentEntry < RawEntry
        def initialize(str)
          super(str[2..-1])
        end
        def comment?
          true
        end
        def to_s
          "//#{@content}"
        end
        def self.condition(str)
          str.start_with?('//')
        end
        register_checker(self,&method(:condition))
      end
      class KeyEntry < Entry
        attr_accessor :key
        attr_accessor :value
        def initialize(str)
          @key, @value = str.split(/\s*:\s*/,2)
        end
        def to_s
          sprintf("%s: %s", @key, @value)
        end
        def self.condition(str)
          /\S+\s*:\s*.+/.match(str)
        end
        register_checker(self,&method(:condition))
      end
      class SplitEntry < Entry
        def initialize(str)
          super
          @args = str.split(self.class.splitter,-1)
        end
        private
        def _upcast(val,key=nil)
          if val.nil? then
            ""
          else
            Integer(val,10) rescue (Float(val)) rescue String(val)
          end
        end
        def _downcast(val)
          String(val)
        end
        public
        def [](key)
          _upcast(@args[key],key)
        end
        def [](key, value)
          @args[key] = _downcast(value)
        end
        def to_s
          @args.join(self.class.splitter)
        end
        class << self
          def abstract?
            true
          end
          def method_added(meth)
            case meth
            when :_upcast, :_downcast
              private meth
            end
          end
          def splitter=(sep)
            @splitter = sep
          end
          def splitter
            @splitter
          end
        end
      end
      class CommaSplitEntry < SplitEntry
        private
        # upcast the value from osu string
        def _upcast(val,key=nil)
          case val
          when /^".*"$/
            val.size <= 2 ? "" : val[1...-1]
          end
          super
        end
        # downcast the value to osu string
        def _downcast(val)
          case val
          when String
            34.chr + val + 34.chr
          when Rational
            String(val.to_f)
          else
            super
          end
        end
        self.splitter = ','
      end
      class BarSplitEntry < Entry
        self.splitter = '|'
      end
      class ColonSplitEntry < Entry
        self.splitter = ':'
      end
    
      class Section
        @_entry = Entry
        attr_accessor :name
        attr_reader   :contents
        def initialize(name, str)
          @name = name
          @contents = str.split(/$/).map(&self.class.entry.method(:determine))
        end
        def to_s
          sprintf("[%1$s]%2$s%3$s",
            @name, $/,
            @contents.join($/)
          )
        end
        class << self
          def entry
            @_entry
          end
          def inherited(cls)
            cls.class_exec do
              def entry=(cls)
                fail TypeError, "expected cls is a class!" unless cls.is_a?(Class)
                fail TypeError, "expected cls to Entry class!" unless cls <= Entry
                @_entry = cls
              end
            end
          end
        end
      end
      class RawSection < Section
        self.entry = RawEntry
      end
      class KVSection < Section
        self.entry = KeyEntry
      end
      class CommaSplitSection < Section
      end
      class FileData < OsuRuby::Parser::TextParser
        attr_reader :sections
        def initialize(str)
          parse_sections(str)
        end
        def parse_sections(str)
          (@sections ||= []).clear
          raw_sections = []
          section_name = nil
          section_content = []
          str.each_line do |line|
            case line
            when /^\[.+\]$/
              unless section_name.nil?
                raw_sections << [section_name, section_content.dup]
              end
              section_content.clear
              section_name = line.chomp[1...-1]
            else
              next if section_name.nil?
              section_content << line.chomp
            end
          end
          raw_sections << [section_name, section_content]
          raw_sections.each do |n,c|
            @sections << Section.new(n, c.join($/))
          end
        end
      end
    end
  end
end
