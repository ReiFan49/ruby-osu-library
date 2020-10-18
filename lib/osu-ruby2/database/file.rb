require 'osu-ruby2/io/dotnet'
module OsuRuby
  module Database
    # @api private
    #
    # This is base of database reading.
    # Please understand this page were meant for developers of this library.
    # But you can try understanding this part for other references.
    #
    # First of all, this database must be used with care. I only provide references
    # or personal data fixes. I do not condone cheating in osu!, please understand.
    # Any misconducts that is done by using this library, I nor the devs, do not give
    # consent for doing so.
    #
    # Second, for any changes that happens within osu! database file itself
    # they may not be noted in here due to some reasons. If any of you wanted to
    # fill out the blankness from any version range, feel free to let me know.
    #
    # Please do not use :send commands to invoke those privates, because they are part of
    # private API. They are not meant to return value, being used outside :read_file
    # or :write_to_file function.
    #
    # Data structure itself are build by peppy and his dev team.
    class BaseDB
      include Interface::AbstractClass
      self.abstract!
      attr_reader :version
      def initialize(file = nil)
        super
        @version = 0
        @file = file
      end
      def version!; @version = GAME_VERSION; end
      def read_file(file = nil)
        need_close = true
        case file
        when nil
          io = IO::DotNetIO.new(File.open(@file,'rb'))
        when String
          @file = file
          io = IO::DotNetIO.new(File.open(@file,'rb'))
        when ::IO
          io = IO::DotNetIO.new(file)
          need_close = false
        end
        @version = io.read_signed_long
        read_content(io)
        io&.eof?
      ensure
        io.close if need_close
      end
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
        when ::IO
          io = IO::DotNetIO.new(file)
          need_close = false
        end
        io.write_signed_long(@version)
        write_content(io)
        true
      ensure
        io.close if need_close
        @file = orig_file if need_revert
      end
      private
      abstract_method :read_content
      abstract_method :write_content
      def read_structs(io, &block)
        size = io.read_signed_long
        array = []
        size.times do |i|
          array.push(block.call)
        end
        array
      end
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
          determine_struct_bytes(io, item)
        end
        true
      end
      abstract_method :determine_struct_bytes
      public
      def inspect
        "<#{self.class.name}>"
      end
      class << self
        def load(file)
          db = new(file)
          db.read_file
          db
        end
      end
    end
    # osu database
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
        osu:    20150211,
      	taiko:  20140610,
      	fruits: 20141123,
      	mania:  20150110
      }
      # this is a temporary number. anyone who knows it pls help
      # even 2012 DB is compatible thanks to this :asahiGa:
      VERSION_BEATMAP_SIZE = 20150817..20191106
      # extra footer addition (useful for offline locks)
      VERSION_FLAG_CACHE = 20141028
      attr_reader :map_list
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
        (@map_list = []).clear
        read_structs(io) do
          struct = {_type: 'Beatmap'}
          if VERSION_BEATMAP_SIZE.include? @version then
            struct.store 'FileSize', io.read_signed_long
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
          struct.store 'Font', io.read_dotnet_osu_string
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
        end.tap do |ary| @map_list.concat(ary) end
      end
      # To understand this, let me point this out.
      # This difficulty calculation comes when Tom94 become a dev for this.
      # Prior to this, difficulty star uses eyup star, which the calculation
      # won't be placed in this library for a reason.
      #
      # So apparently there are several checkers to load the counter.
      # - Does the version support difficulty rating cache?
      # - Does the version uses Enum/Flags implementation on it?
      # - Does the version uses
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
        struct = struct.dup
        type = struct.delete(:_type)
        case type
        when 'Beatmap'
          if VERSION_BEATMAP_SIZE.include? @version then
            io.write_signed_long struct.delete('FileSize')
          end
          io.write_dotnet_osu_string struct.delete('Artist')
          if @version >= VERSION_UNICODE then
            io.write_dotnet_osu_string struct.delete('ArtistUnicode')
          end
          io.write_dotnet_osu_string struct.delete('Title')
          if @version >= VERSION_UNICODE then
            io.write_dotnet_osu_string struct.delete('TitleUnicode')
          end
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
            size = 3
            if @version >= VERSION_MODE_MANIA then
              size = 4
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
          io.write_dotnet_osu_string struct.delete('Font')
          io.write_boolean struct.delete('Unplayed')
          io.write_dotnet_time struct.delete('LastPlay')
          io.write_boolean struct.delete('osz2')
          io.write_dotnet_osu_string struct.delete('FolderPath')
          io.write_dotnet_time struct.delete('LastCheck')
          if @version > VERSION_PERSET then
            io.write_boolean struct.delete('IgnoreHS')
            io.write_boolean struct.delete('IgnoreSkin')
            io.write_boolean struct.delete('IgnoreSB')
            if @version >= VERSION_PERSET_VIDEO then
              io.write_boolean struct.delete('IgnoreVideo')
            end
            if @version >= VERSION_PERSET_OVERRIDE then
              io.write_boolean struct.delete('IgnoreVisual')
            end
            if @version < VERSION_PERSET_NO_DIM then
              io.write_short struct.delete('DimRate')
            end
          end
          if @version > VERSION_EDITOR_TIME then
            io.write_long struct.delete('EditorTime')
          end
          if @version >= VERSION_MODE_MANIA then
            io.write_byte struct.delete('ManiaSpeed')
          end
        when 'DifficultyRating'
          io.write_expect(8, struct.delete('Mods'), 13, struct.delete('Rating'))
        when 'TimingPoints'
          io.write_double struct.delete('BPM')
          io.write_double struct.delete('Offset')
          io.write_boolean struct.delete('Toggle')
        end
        struct.clear
      end
      def write_beatmaps(io)
        write_structs(io, @map_list)
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
        if @version >= VERSION_FLAG_CACHE then
          io.write_long @acc_role
        end
      end
    end
    class ScoreDB < BaseDB
    end
    class CollectionDB < BaseDB
    end
  end
end
