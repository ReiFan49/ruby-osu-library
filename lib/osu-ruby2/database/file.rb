require 'osu-ruby2/io/dotnet'
module OsuRuby
  module Database
    # @abstract This is base of database reading.
    #   Please understand this page were meant for developers of this library.
    #   But you can try understanding this part for other references.
    #
    # @note First of all, this database must be used with care. I only provide references
    #   or personal data fixes. I do not condone cheating in osu!, please understand.
    #   Any misconducts that is done by using this library, I nor the devs, do not give
    #   consent for doing so.
    #
    #   Second, for any changes that happens within osu! database file itself
    #   they may not be noted in here due to some reasons. If any of you wanted to
    #   fill out the blankness from any version range, feel free to let me know.
    #
    #   Please do not use :send commands to invoke those privates, because they are part of
    #   private API. They are not meant to return value, being used outside :read_file
    #   or :write_to_file function.
    #
    #   Data structure itself are build by peppy and his dev team.
    class BaseDB
      include Interface::AbstractClass
      self.abstract!
      # Represents database version
      attr_reader :version
      # Instantiate a simple skeleton
      def initialize(file = nil)
        super
        @version = 0
        @file = file
      end
      def initialize_copy(other)
        @file = nil
        super
      end
      # Enforces the database version to the library-supported one.
      # @return [void]
      def version!; @version = GAME_VERSION; end
      # Read from source
      # @overload read_file()
      #   Opens a previously assigned filename database. Closes IO after use.
      # @overload read_file(filename)
      #   Opens an existing database. This will change the internal filename pointer.
      #   Closes IO after use.
      #   @param filename [String] a representation of a filename
      # @overload read_file(dotnet_io)
      #   Pass the baton of the DotNetIO usage. Using this will not close the IO aftermath.
      #   @param dotnet_io [IO::DotNetIO] a DotNetIO to share
      # @overload read_file(io)
      #   Reads from existing IO object. Using this will not close the IO aftermath.
      #   @param io [::IO] any IO object (meant for StringIO but others sure)
      # @return [Boolean] EOF-check
      def read_file(file = nil)
        need_close = true
        case file
        when nil
          io = IO::DotNetIO.new(File.open(@file,'rb'))
        when String
          @file = file
          io = IO::DotNetIO.new(File.open(@file,'rb'))
        when IO::DotNetIO
          io = file
          need_close = false
        when ::IO
          io = IO::DotNetIO.new(file)
          need_close = false
        end
        read_precontent(io)
        @version = io.read_signed_long
        read_content(io)
        io&.eof?
      ensure
        io.close if need_close
      end
      # Write database to destination
      # @overload write_to_file()
      #   Writes to previously assigned filename database. Closes IO after use.
      # @overload write_to_file(filename)
      #   Writes into a new database. This will +not+ change the internal filename pointer.
      #   Closes IO after use.
      #   @param filename [String] a representation of a filename
      # @overload write_to_file(dotnet_io)
      #   Pass the baton of the DotNetIO usage. Using this will not close the IO aftermath.
      #   @param dotnet_io [IO::DotNetIO] a DotNetIO to share
      # @overload write_to_file(io)
      #   Writes existing IO object. Using this will not close the IO aftermath.
      #   @param io [::IO] any IO object (meant for StringIO but others sure)
      # @return [void]
      def write_to_file(file = nil)
        need_close = true
        need_revert = false
        case file
        when nil
          io = IO::DotNetIO.new(File.open(@file,'wb'))
        when String
          orig_file, @file = @file, file
          io = IO::DotNetIO.new(File.open(@file,'wb'))
          need_revert = true
        when IO::DotNetIO
          io = file
          need_close = false
        when ::IO
          io = IO::DotNetIO.new(file)
          need_close = false
        end
        write_precontent(io)
        io.write_signed_long(@version)
        write_content(io)
        true
      ensure
        io.close if need_close
        @file = orig_file if need_revert
      end
      private
      # To read extra data before file version.
      def read_precontent(io); end
      # To write extra data before file version.
      def write_precontent(io); end
      
      abstract_method :read_content
      abstract_method :write_content
      # @!visibility public
      # @api private
      # This allows to read an array of object to be read consecutively.
      # First Int32 signifies the length of the array, after that perform
      # the given block (must, no sanity check).
      # @overload read_structs(io, &block)
      #   @param io [IO::DotNetIO] a recurring DotNetIO to use
      #   @param block [Proc] a block to process how the struct is processed onwards.
      #   @return [Array] with consistent struct data.
      # @overload read_structs(io, container, &block)
      #   @param io [IO::DotNetIO] a recurring DotNetIO to use
      #   @param container [Array] container to store directly all the values returned by the block
      #   @param block [Proc] a block to process how the struct is processed onwards.
      #   @return [void]
      def read_structs(io, container = nil, &block)
        size = io.read_signed_long
        array = []
        size.times do |i|
          array.push(block.call)
        end
        if container then
          container.concat(array)
          return
        end
        array
      end
      # @!visibility public
      # @api private
      # @note Do not overload this method. Instead, implement the #determine_struct_bytes, things are handled there.
      # This function only removes some parts that can be considered as repetitive.
      # @param io [IO::DotNetIO] a recurring DotNetIO to use
      # @param list [Hash] the struct to pass on
      # @raise [TypeError] sanity-check when there are more than one-struct type inside the struct container.
      #   Consider you are doing it wrong.
      # @see #determine_struct_bytes
      def write_structs(io, list)
        io.write_signed_long(list.size)
        struct_unique = list.map do |item| item[:_type] end.uniq.size
        case struct_unique
        when 0
          return true
        when 1
          # keep going
        else
          fail TypeError, "Cannot accept multiple struct type in a list."
        end
        list.each do |item|
          item2 = item.dup
          determine_struct_bytes(io, item2)
          item2.clear
        end
        true
      end
      # @!visibility public
      # @abstract For developers, please refer this function when handling the
      #   "array of"s a.k.a things passed from #write_struct, as how the implementation
      #   already gives you the list size without worrying about it beforehand.
      #
      # This method itself uses case/when structure in general, but the further implementation
      #   is free.
      # @!method determine_struct_bytes(io, item)
      #   @abstract
      #   @api private
      #   @param io [IO::DotNetIO] a recurring DotNetIO to use
      #   @note There's no sanity check for this, as it's supposed to have a proper
      #     Hash-struct-like format. For the convention, each type always starts with
      #     +:_type+ key that signifies struct type itself.
      #   @param item [Hash] the struct to pass on
      #   @return [void]
      abstract_method :determine_struct_bytes
      public
      # @return [String]
      def inspect
        "<#{self.class.name}>"
      end
      class << self
        # Loads the database from the file directly
        # @return [BaseDB]
        def load(file)
          db = new(file)
          db.read_file
          db
        end
      end
    end
    # osu! database
    class OsuDB < BaseDB
      # osu v10 in general
      VERSION_UNICODE = 20121008
      # mania to real public (had been in osu!test for more than 10 months)
      VERSION_MODE_MANIA = 20121008
      # extra header addition
      VERSION_HEADER_UP = 20121023
      # editor time feature
      VERSION_EDITOR_TIME = 20121009
      # Fun Spoilers/Visual Settings implementation
      VERSION_PERSET = 20120620
      # Fun Spoilers/No Video support
      VERSION_PERSET_VIDEO = 20130624
      # Fun Spoilers/Visual Override Flag
      VERSION_PERSET_OVERRIDE = 20130913
      # Fun Spoilers/Dim Availability (up to 20140608)
      VERSION_PERSET_NO_DIM = 20140608
      # Difficulty/Internal/Store AR
      VERSION_DIFFICULTY_STORE_AR = 20120620
      # Difficulty/Internal/New Calculation
      VERSION_DIFFICULTY_CACHE = 20140609
      # Difficulty/Internal/ModFlag to IntFlag
      VERSION_DIFFICULTY_CACHE_STYLE = 20140610
      # Difficulty/Internal/ModFlag to IntFlag
      VERSION_DIFFICULTY_PRECISE = 20140612
      # Difficulty/Internal/Force Clear Cache
      VERSION_DIFFICULTY_FORCE_RECHECK = {
        osu:    [20150211, 20160722],
        taiko:  20140610,
        fruits: 20141123,
        mania:  20150110,
      }
      # this is a temporary number. anyone who knows it pls help
      # even 2012 DB is compatible thanks to this :asahiGa:
      VERSION_BEATMAP_SIZE = 20160408..20191106
      # extra footer addition (useful for offline locks)
      VERSION_FLAG_CACHE = 20141028
      attr_reader :contents
      private
      def read_content(io)
        read_header(io)
        read_beatmaps(io)
        read_footer(io)
      end
      def read_header(io)
        @folder_count = io.read_signed_long
        if @version >= VERSION_HEADER_UP then
          @acc_status  = io.read_boolean
          @acc_time    = io.read_dotnet_time
          @player_name = io.read_dotnet_osu_string
        else
          @acc_status  = true
          @acc_time    = Time.at(0)
          @player_name = ENV['USERNAME']
        end
      end
      def read_beatmaps(io)
        (@contents = []).clear
        read_structs(io, @contents) do
          struct = {_type: 'Beatmap'}
          if VERSION_BEATMAP_SIZE.include? @version then
            struct.store 'EntrySize', io.read_signed_long
          end
          struct.store 'Artist', io.read_dotnet_osu_string
          if @version >= VERSION_UNICODE then
            struct.store 'ArtistUnicode', io.read_dotnet_osu_string
          else
            struct.store 'ArtistUnicode', struct.fetch('Artist')
          end
          struct.store 'Title', io.read_dotnet_osu_string
          if @version >= VERSION_UNICODE then
            struct.store 'TitleUnicode', io.read_dotnet_osu_string
          else
            struct.store 'TitleUnicode', struct.fetch('Artist')
          end
          struct.store 'Creator', io.read_dotnet_osu_string
          struct.store 'Difficulty', io.read_dotnet_osu_string
          struct.store 'FileSong', io.read_dotnet_osu_string
          struct.store 'MD5', io.read_dotnet_osu_string
          struct.store 'FileMap', io.read_dotnet_osu_string
          struct.store 'Submission', io.read_byte
          %w(Circle Slider Spinner).each do |k|
            struct.store "Count#{k}", io.read_signed_short
          end
          struct.store 'MTime', io.read_dotnet_time
          diff_key = %w(HP CS OD)
          diff_key.unshift('AR') if @version >= VERSION_DIFFICULTY_STORE_AR
          diff_key.each do |k|
            if @version >= VERSION_DIFFICULTY_PRECISE then
              struct.store k, io.read_single
            else
              struct.store k, io.read_byte
            end
          end
          struct.store 'SV', io.read_double
          struct.store 'DifficultyCache', read_difficulty_dictionary(io)
          struct.store 'TimeDrain', io.read_long
          struct.store 'TimeTotal', io.read_long
          struct.store 'TimePreview', io.read_long
          struct.store 'TimingPoints', read_timing(io)
          struct.store 'IDMap', io.read_long
          struct.store 'IDMapset', io.read_long
          struct.store 'IDThread', io.read_long
          if @version >= VERSION_MODE_MANIA then
            struct.store 'Ranking', Array.new(4){io.read_byte}
          else
            struct.store 'Ranking', Array.new(3){io.read_byte}
          end
          struct.store 'OffsetLocal', io.read_signed_short
          struct.store 'Stack', io.read_single
          struct.store 'Mode', io.read_byte
          struct.store 'Source', io.read_dotnet_osu_string
          struct.store 'Tags', io.read_dotnet_osu_string
          struct.store 'OffsetGlobal', io.read_signed_short
          struct.store 'OnlineTitle', io.read_dotnet_osu_string
          struct.store 'Unplayed', io.read_boolean
          struct.store 'LastPlay', io.read_dotnet_time
          struct.store 'osz2', io.read_boolean
          struct.store 'FolderPath', io.read_dotnet_osu_string
          struct.store 'LastCheck', io.read_dotnet_time
          if @version > VERSION_PERSET then
            struct.store 'IgnoreHS', io.read_boolean
            struct.store 'IgnoreSkin', io.read_boolean
            struct.store 'IgnoreSB', io.read_boolean
            if @version >= VERSION_PERSET_VIDEO then
              struct.store 'IgnoreVideo', io.read_boolean
            else
              struct.store 'IgnoreVideo', false
            end
            if @version >= VERSION_PERSET_OVERRIDE then
              struct.store 'IgnoreVisual', io.read_boolean
            else
              struct.store 'IgnoreVisual', struct.values_at('IgnoreSkin','IgnoreSB','IgnoreVideo').inject(false,:|)
            end
            if @version <  VERSION_PERSET_NO_DIM then
              struct.store 'DimRate', io.read_short
            end
          end
          if @version > VERSION_EDITOR_TIME then
            struct.store 'EditorTime', io.read_long
          end
          if @version >= VERSION_MODE_MANIA then
            struct.store 'ManiaSpeed', io.read_byte
          end
          struct
        end
      end
      # To understand this, let me point this out.
      # This difficulty calculation comes when Tom94 become a dev for this.
      # Prior to this, difficulty star uses eyup star, which the calculation
      # won't be placed in this library for a reason.
      #
      # So apparently there are several checkers to load the counter.
      # - Does the version support difficulty rating cache?
      # - Does the version uses Enum/Flags implementation on it?
      # - Does the latest version requires to enforce recalculation?
      def read_difficulty_dictionary(io)
        difficulty = BASE_MODES.map do |m| [m, []] end.to_h
        if @version >= VERSION_DIFFICULTY_CACHE then
          BASE_MODES.each do |m|
            mods = difficulty[m]
            # Not implemented from version
            if @version < VERSION_DIFFICULTY_CACHE_STYLE then
              read_difficulty_star(io)
            # Need force recheck - global settings
            elsif Integer === VERSION_DIFFICULTY_FORCE_RECHECK && @version < VERSION_DIFFICULTY_FORCE_RECHECK then
              read_difficulty_star(io)
            # Need force recheck - per-mode settings
            elsif Hash === VERSION_DIFFICULTY_FORCE_RECHECK && Integer === VERSION_DIFFICULTY_FORCE_RECHECK[m] && @version < VERSION_DIFFICULTY_FORCE_RECHECK[m] then
              read_difficulty_star(io)
            # Need force recheck - per-mode versioned settings
            elsif Hash === VERSION_DIFFICULTY_FORCE_RECHECK && Array === VERSION_DIFFICULTY_FORCE_RECHECK[m] && @version < VERSION_DIFFICULTY_FORCE_RECHECK[m].max then
              read_difficulty_star(io)
            # Just load
            else
              mods.replace(read_difficulty_star(io))
            end
          end
        end
        difficulty
      end
      def read_difficulty_star(io)
        read_structs(io) do
          struct = {_type: 'DifficultyRating'}
          struct.store 'Mods', io.read_osu_type
          struct.store 'Rating', io.read_osu_type
          struct
        end
      end
      def read_timing(io)
        read_structs(io) do
          struct = {_type: 'TimingPoints'}
          struct.store 'BPM', io.read_double
          struct.store 'Offset', io.read_double
          struct.store 'Toggle', io.read_boolean
          struct
        end
      end
      def read_footer(io)
        if @version >= VERSION_FLAG_CACHE then
          @acc_role = io.read_long
        else
          @acc_role = 0
        end
      end
      def write_content(io)
        write_header(io)
        write_beatmaps(io)
        write_footer(io)
      end
      def write_header(io)
        io.write_signed_long(@folder_count)
        if @version >= VERSION_HEADER_UP then
          io.write_boolean @acc_status
          io.write_dotnet_time @acc_time
          io.write_dotnet_osu_string @player_name
        end
      end
      def determine_struct_bytes(io, struct)
        type = struct.delete(:_type)
        case type
        when 'Beatmap'
          if VERSION_BEATMAP_SIZE.include? @version then
            io.write_signed_long struct.delete('EntrySize')
          end
          io.write_dotnet_osu_string struct.delete('Artist')
          io.write_dotnet_osu_string struct.delete('ArtistUnicode') if @version >= VERSION_UNICODE
          io.write_dotnet_osu_string struct.delete('Title')
          io.write_dotnet_osu_string struct.delete('TitleUnicode') if @version >= VERSION_UNICODE
          io.write_dotnet_osu_string struct.delete('Creator')
          io.write_dotnet_osu_string struct.delete('Difficulty')
          io.write_dotnet_osu_string struct.delete('FileSong')
          io.write_dotnet_osu_string struct.delete('MD5')
          io.write_dotnet_osu_string struct.delete('FileMap')
          io.write_byte struct.delete('Submission')
          %w(Circle Slider Spinner).each do |k|
            io.write_signed_short struct.fetch("Count#{k}")
          end
          io.write_dotnet_time struct.delete('MTime')
          diff_key = %w(HP CS OD)
          diff_key.unshift('AR') if @version >= VERSION_DIFFICULTY_STORE_AR
          diff_key.each do |k|
            if @version >= VERSION_DIFFICULTY_PRECISE then
              io.write_single struct.delete(k)
            else
              io.write_byte struct.delete(k)
            end
          end
          io.write_double struct.delete('SV')
          write_difficulty_dictionary(io, struct.delete('DifficultyCache'))
          io.write_long struct.delete('TimeDrain')
          io.write_long struct.delete('TimeTotal')
          io.write_long struct.delete('TimePreview')
          write_timing(io, struct.delete('TimingPoints'))
          io.write_long struct.delete('IDMap')
          io.write_long struct.delete('IDMapset')
          io.write_long struct.delete('IDThread')
          struct.delete('Ranking').tap do |array|
            if @version >= VERSION_MODE_MANIA then
              size = 4
            else
              size = 3
            end
            array.fill(0, array.size, size - array.size).slice!(size..-1)
          end.each do |rank|
            io.write_byte rank
          end
          io.write_signed_short struct.delete('OffsetLocal')
          io.write_single struct.delete('Stack')
          io.write_byte struct.delete('Mode')
          io.write_dotnet_osu_string struct.delete('Source')
          io.write_dotnet_osu_string struct.delete('Tags')
          io.write_signed_short struct.delete('OffsetGlobal')
          io.write_dotnet_osu_string struct.delete('OnlineTitle')
          io.write_boolean struct.delete('Unplayed')
          io.write_dotnet_time struct.delete('LastPlay')
          io.write_boolean struct.delete('osz2')
          io.write_dotnet_osu_string struct.delete('FolderPath')
          io.write_dotnet_time struct.delete('LastCheck')
          if @version > VERSION_PERSET then
            io.write_boolean struct.delete('IgnoreHS')
            io.write_boolean struct.delete('IgnoreSkin')
            io.write_boolean struct.delete('IgnoreSB')
            io.write_boolean struct.delete('IgnoreVideo') if @version >= VERSION_PERSET_VIDEO
            io.write_boolean struct.delete('IgnoreVisual') if @version >= VERSION_PERSET_OVERRIDE
            io.write_short struct.delete('DimRate') if @version < VERSION_PERSET_NO_DIM
          end
          io.write_long struct.delete('EditorTime') if @version > VERSION_EDITOR_TIME
          io.write_byte struct.delete('ManiaSpeed') if @version >= VERSION_MODE_MANIA
        when 'DifficultyRating'
          io.write_expect(8, struct.delete('Mods'), 13, struct.delete('Rating'))
        when 'TimingPoints'
          io.write_double struct.delete('BPM')
          io.write_double struct.delete('Offset')
          io.write_boolean struct.delete('Toggle')
        end
        nil
      end
      def write_beatmaps(io)
        write_structs(io, @contents)
      end
      def write_difficulty_dictionary(io, list)
        if @version >= VERSION_DIFFICULTY_CACHE then
          BASE_MODES.each do |m|
            write_difficulty_star(io, list[m])
          end
        end
      end
      def write_difficulty_star(io, item)
        write_structs(io, item)
      end
      def write_timing(io, list)
        write_structs(io, list)
      end
      def write_footer(io)
        io.write_long @acc_role if @version >= VERSION_FLAG_CACHE
      end
    end
    # Representation of osu replay data.
    class ReplayData < BaseDB
      # inclusion of score ID
      VERSION_REPLAY_ID = 20121008
      VERSION_REPLAY_IDBIG = 20140721
      VERSION_MOD_TARGET = 20140307
      private
      def read_precontent(io)
        @mode = io.read_byte
      end
      def read_content(io)
        read_header(io)
        read_result_screen(io)
        read_replay_content(io)
        read_footer(io)
      end
      def read_header(io)
        @hash_map     = io.read_dotnet_osu_string
        @player_name  = io.read_dotnet_osu_string
        @hash_replay  = io.read_dotnet_osu_string
      end
      def read_result_screen(io)
        (@count_result ||= {}).clear
        @count_result.store  '300', io.read_short
        @count_result.store  '100', io.read_short
        @count_result.store   '50', io.read_short
        @count_result.store 'Geki', io.read_short
        @count_result.store 'Katu', io.read_short
        @count_result.store 'Miss', io.read_short
        @result_score = io.read_signed_long
        @max_combo    = io.read_short
        @flag_fc      = io.read_boolean
        @mods         = io.read_long
        @graph_string = io.read_dotnet_osu_string
        @result_time  = io.read_dotnet_time
      end
      def read_replay_content(io)
        @replay_data  = io.read_byte_array
      end
      def read_footer(io)
        read_replay_id(io)
        read_replay_extras(io)
      end
      def read_replay_id(io)
        if @version >= VERSION_REPLAY_IDBIG then
          @online_id = io.read_long64
        elsif @version >= VERSION_REPLAY_ID then
          @online_id = io.read_long
        end
      end
      def read_replay_extras(io)
        if @version >= VERSION_MOD_TARGET && (@mods & Constants::MODS[:TP]).nonzero? then
          @target_acc = io.read_double
        end
      end
      def write_content(io)
        write_header(io)
        write_result_screen(io)
        write_replay_content(io)
        write_footer(io)
      end
      def write_header(io)
        io.write_dotnet_osu_string(@hash_map)
        io.write_dotnet_osu_string(@player_name)
        io.write_dotnet_osu_string(@hash_replay)
      end
      def write_result_screen(io)
        %w(300 100 50 Geki Katu Miss).each do |k|
          io.write_short @count_result[k]
        end
        io.write_signed_long @result_score
        io.write_short @max_combo
        io.write_boolean @flag_fc
        io.write_long @mods
        io.write_dotnet_osu_string @graph_string
        io.write_dotnet_time @result_time
      end
      def write_replay_content(io)
        io.write_byte_array @replay_data
      end
      def write_footer(io)
        write_replay_id(io)
        write_replay_extras(io)
      end
      def write_replay_id(io)
        if @version >= VERSION_REPLAY_IDBIG then
          io.write_long64 @online_id
        elsif @version > VERSION_REPLAY_ID then
          io.write_long @online_id
        end
      end
      def write_replay_extras(io)
        if (@mods & 0x800000).nonzero? then
          io.write_double @target_acc
        end
      end
      public
      # Safely discards replay info by creating a similar instance beforehand.
      # @return [ReplayData] a discarded replay of ReplayData
      # @see #discard_replay_info!
      def discard_replay_info
        dup.discard_replay_info!
      end
      # Destructively discards replay info from the replay data.
      # @return [self]
      # @see #discard_replay_info
      def discard_replay_info!
        @replay_data = nil
        @online_id = 0
        self
      end
      class << self
        # @return [ReplayData]
        def load(io)
          db = new
          db.read_file(io)
          db
        end
      end
    end
    # @note If you ever tried to write things from this class. Seriously,
    # you need some work than that.
    class ReplayGraph < BaseDB
      # I don't know
      VERSION_COMPRESS = 20160101
      private
      def read_content(io)
        read_replay_graphs(io)
      end
      def read_replay_graphs(io)
        (@contents ||= []).clear
        read_structs(io, @contents) do
          struct = {_type: 'ReplayGraph'}
          struct.store 'Time', io.read_signed_long
          struct.store 'NoGauge', io.read_byte
          %w(300 100 50 Geki Katu Miss).each do |k|
            struct.store "Count#{k}", io.read_short
          end
          struct.store 'Score', io.read_long
          struct.store 'ComboMax', io.read_short
          struct.store 'ComboNow', io.read_short
          struct.store 'Finished', io.read_boolean
          struct.store 'LifeGauge', io.read_byte
          if @version < VERSION_COMPRESS then
            struct.store 'HitType', io.read_signed_long
          else
            struct.store 'HitType', io.read_signed_short
          end
        end
      end
      def determine_struct_bytes(io, item)
        type = struct.delete(:_type)
        case type
        when 'ReplayGraph'
          io.write_signed_long struct.delete('Time')
          io.write_byte struct.delete('NoGauge')
          %w(300 100 50 Geki Katu Miss).each do |k|
            io.write_short struct.delete("Count#{k}")
          end
          io.write_long struct.delete('Score')
          io.write_short struct.delete('ComboMax')
          io.write_short struct.delete('ComboNow')
          io.write_boolean struct.delete('Finished')
          io.write_byte struct.delete('LifeGauge')
          if @version < VERSION_COMPRESS then
            io.write_signed_long struct.delete('HitType')
          else
            io.write_signed_short struct.delete('HitType')
          end
        end
        true
      end
      def write_content(io)
        write_replay_graphs(io)
      end
      def write_replay_graphs(io)
        write_structs(io, @contents)
      end
    end
    class ScoreDB < BaseDB
      attr_reader :contents
      private
      def read_content(io)
        read_beatmaps(io)
      end
      def read_beatmaps(io)
        (@contents ||= {}).clear
        read_structs(io, @contents) do
          struct = {_type: 'ScoreSet'}
          struct.store 'BMHash', io.read_dotnet_osu_string
          struct.store 'BMScores', read_scores(io)
          struct
        end
      end
      def read_scores(io)
        read_structs(io) do
          struct = {_type: 'ScoreData'}
          struct.store 'ReplayData', ReplayData.load(io)
          struct
        end
      end
      def determine_struct_bytes(io, struct)
        type = struct.delete(:_type)
        case type
        when 'ScoreSet'
          io.write_dotnet_osu_string struct.delete('BMHash')
          write_scores(struct.delete('BMScores'))
        when 'ScoreData'
          replay = struct.delete('ReplayData')
          replay.write_to_file(io)
        end
      end
      def write_content(io)
        write_beatmaps(io)
      end
      def write_beatmaps(io)
        write_structs(io, @contents)
      end
      def write_scores(io, list)
        write_structs(io, list)
      end
    end
    class CollectionDB < BaseDB
      attr_reader :contents
      private
      def read_content(io)
        read_collections(io)
      end
      def read_collections(io)
        (@contents ||= []).clear
        read_structs(io, @contents) do
          struct = {_type: 'CollectionData'}
          struct.store 'Name', io.read_dotnet_osu_string
          struct.store 'Content', read_collection_hash(io)
          struct
        end
      end
      def read_collection_hash(io)
        read_structs(io) do
          struct = {_type: 'BMRef'}
          struct.store 'Hash', io.read_dotnet_osu_string
        end
      end
      def determine_struct_bytes(io, struct)
        type = struct.delete(:_type)
        case type
        when 'CollectionData'
          io.write_dotnet_osu_string struct.delete('Name')
          write_collection_hash(io, struct.delete('Content'))
        when 'BMRef'
          io.write_dotnet_osu_string struct.delete('Hash')
        end
        nil
      end
      def write_content(io)
        write_collections(io)
      end
      def write_collections(io)
        write_structs(io, @contents)
      end
      def write_collection_hash(io, list)
        write_structs(io, list)
      end
    end
  end
end
