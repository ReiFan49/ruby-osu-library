module OsuRuby
  module Parser
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
    # A class dictated with ability to parse given text content
    # and convert-back into the given string format using +#to_s+ .
    #
    # @abstract This class is meant for parser base system and
    #   a global registry for all of it's descendants.
    class Entry
      include Interface::AbstractClass
      # checks whether entry does not need further parsing
      # @return [Boolean]
      def comment?
        false
      end
      class << self
        # checks applicable condition for matching
        # @param str [String] string to match
        # @return [Boolean, nil]
        def condition(str)
          nil
        end
        # Method hook invoked upon inheritance.
        #
        # Performs following actions:
        #
        # * Automatically unmarks class as abstract. Unless defined again. (To be removed.)
        # * Shadows {.determine} function into {.initialize}.
        # * Aliaases {.register_checker} function to use {Entry#register_checker} instead.
        # @return [void]
        def inherited(cls)
          super
          cls.instance_exec do
            def determine(str)
              new(str)
            end
            def register_checker(cls)
              Entry.register_checker(cls)
            end
          end
        end
        # register an {Entry} subclass to global registry
        # @param cls [Class<Entry>] {Entry} subclass
        # @return [void]
        def register_checker(cls)
          return unless cls < Entry
          @_class_map ||= []
          @_class_map << cls
          true
        end
        # parses given string into a proper parser class.
        # @note this function is overridden on subclasses into an alias of +new+.
        # @return [Entry]
        def determine(str)
          entry = @_class_map.find do |cls|
            cls.condition(str)
          end
          
          if entry.nil? then
            RawEntry.determine(str)
          else
            entry.determine(str)
          end
        end
      end
      
      self.abstract!
    end
    # "No Parsing" parser.
    #
    # Always used as fallback during {Entry.determine} function.
    class RawEntry < Entry
      # original string without any special strings to be returned.
      # @return [String]
      attr_accessor :content
      
      # store content within n parsing wrapper.
      # @param str [String]
      def initialize(str)
        super
        @content = str
      end
      # @return [String] original content
      def to_s
        @content
      end
      # @return [Boolean] always returns +true+
      def self.condition(str)
        true
      end
    end
    # Comment based parser.
    class CommentEntry < RawEntry
      def initialize(str)
        super(str.sub(%r[^//\s*], ''))
      end
      # marks given entry are comment type.
      # @return [Boolean]
      def comment?
        true
      end
      # @return [String] retains comment marker for given string.
      def to_s
        "//#{@content}"
      end
      # checks whether given string is a comment or not.
      # @return [Boolean]
      def self.condition(str)
        str.start_with?('//')
      end
      register_checker self, &method(:condition)
    end
    # Key-Value based parser.
    #
    # Splits key and value between first colon found.
    class KeyEntry < Entry
      # @return [String]
      attr_accessor :key
      # @return [String]
      attr_accessor :value
      
      # splits string into a key-value pair data.
      # @param str [String]
      def initialize(str)
        super
        @key, @value = str.split(/\s*:\s*/,2)
      end
      # @return [String] key-value pair concatenated with colon
      def to_s
        sprintf("%s: %s", @key, @value)
      end
      # @return [Boolean] checks if given string is a colon separated key-vaue string.
      def self.condition(str)
        /\S+\s*:\s*.+/.match(str)
      end
      register_checker self, &method(:condition)
    end
    # @abstract This is an abstract class of Separator-Split Parser
    class SplitEntry < Entry
      # Splits string based on class {.splitter}.
      # @param str [String]
      def initialize(str)
        super
        @args = str.split(self.class.splitter, -1)
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
      # access the splitter indices
      # @note It's not advised to use negative index as it may lead to
      #   unwanted behavior upon upcasting.
      # @param key [Integer] index of the array.
      # @return [Integer, Float] value after upcasted from String.
      # @return [String] retrieves the string back if the conversion fails.
      def [](key)
        _upcast @args[key], key
      end
      # assigns value to the array
      # @param key [Integer] index of the array
      # @param value [Object] value to be insereted. This value will be converted into a String.
      # @return [void]
      def []=(key, value)
        @args[key] = _downcast(value)
      end
      # @return [String]
      def to_s
        @args.join(self.class.splitter)
      end
      class << self
        # automatically private methods for {#_upcast} and {#_downcast}.
        # @return [void]
        def method_added(meth)
          case meth
          when :_upcast, :_downcast
            private meth
            return
          end
          super
        end
        # configures the class splitter.
        # @param sep [String] string separator.
        # @return [void]
        def splitter=(sep)
          @splitter = sep
        end
        # obtain the class splitter.
        # @return [String]
        def splitter
          @splitter
        end
      end
      self.abstract!
    end
    # Comma-based (+,+) separator parser.
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
    # Bar-based (+|+) separator parser.
    class BarSplitEntry < SplitEntry
      self.splitter = '|'
    end
    # Colon-based (+:+) separator parser.
    class ColonSplitEntry < SplitEntry
      self.splitter = ':'
    end
    
    # A {Section} dictates a group of string line to be parsed using one {Entry} class parser.
    class Section
      @_entry = Entry
      # @return [String] section name
      attr_accessor :name
      # @return [Array<Entry>] parsed contents.
      attr_reader   :contents
      
      # @param name [String] section name
      # @param str [String] piece of section to be parsed.
      def initialize(name, str)
        @name = name
        @contents = str.split(/$/).map(&:strip).map(&self.class.entry.method(:determine))
      end
      # @return [String] section content converted into osu!-compatible string.
      def to_s
        sprintf("[%1$s]%2$s%3$s",
          @name, $/,
          @contents.join($/)
        )
      end
      class << self
        # @return [Class<Entry>] entry class that represents the available parser.
        def entry
          @_entry
        end
        # Upon inheriting, subclasses can use +#entry=+ function to configure
        # the expected Entry class to parse the strings.
        # @return [void]
        def inherited(cls)
          super
          cls.instance_exec do
            def entry=(cls)
              fail TypeError, "expected cls is a class!" unless cls.is_a?(Class)
              fail TypeError, "expected cls to Entry class!" unless cls <= Entry
              @_entry = cls
            end
          end
        end
      end
    end
    # {Section} that uses only {RawEntry} parser.
    class RawSection < Section
      self.entry = RawEntry
    end
    # {Section} that uses only {KeyEntry} parser.
    class KVSection < Section
      self.entry = KeyEntry
    end
    # @todo work on this.
    class CommaSplitSection < Section
    end
    # Implements basic ability to parse normal file.
    #
    # Parser Core uses 4 functionality to work.
    #
    # * *Reader*, text file to machine variables conversion. Uses {Section} and {Entry} to help.
    # * *Writer*, machine variables to text file. Make a use of {Base#compile_contents} and {Section#to_s}.
    # * *Transformer*, passing machine variables to other machine variables potentially changing its internals.
    #   Simplified the usage through {#sections}
    # * *Converter*, passes machine variables into Behavior specific container that accepts given variables. See {#convert}
    class RawFile < Base
      # @return [Array<Section>] file sections.
      attr_reader :sections
      
      def initialize
        super
        @sections = []
      end
      # parse given IO input to program editable contents
      # @param io [#read] Readable IO stream to parse
      # @return [void]
      def parse(io)
        io.rewind
        parse_header io
        parse_sections io
      end
      # parse file header if any
      # @param io [#read] Readable IO stream to parse
      # @return [void]
      def parse_header(io)
      end
      # parse whole file string and populate the {#sections} variable.
      # @param io [#read] Readable IO stream to parse
      # @return [void]
      def parse_sections(io)
        @sections.clear
        str = io.read
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
        raw_sections.each do |n, c|
          @sections << determine_sections(n, c)
        end
      end
      private
      def determine_sections(section_name, section_contents)
        Section.new(section_name, section_contents.join($/))
      end
      # @!visibility public
      # @private
      # converts parsed data into osu! readable text file.
      # @return [String] osu! text file compatible string.
      def compile_contents
      end
      
      class << self
      end
    end
  end
end
