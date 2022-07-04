# file content mostly copied from skin-reader.rb
require 'osu-ruby2'
require 'osu-ruby2/error'
require 'osu-ruby2/parser'

module OsuRuby::Error
  # No Skin error.
  class SkinNotFoundError < StandardError; end
end
module OsuRuby::Skin
  # osu!skin metadata reader.
  # @todo Fix naming convention for this.
  class Processor
    # osu!skin metadata filename to find
    FILE_NAME = -'skin.ini'
    
    # @param base_dir [String, nil] Expected skin directory to check
    def initialize(base_dir)
      @base_dir  = base_dir || Dir.pwd
      @skin_data = nil
    end
    # Attempts to read +skin.ini+ file.
    # @return [void]
    def process
      skin_dir
      read_file
    end
    # Detected osu!skin folder
    # @!attribute [r] skin_dir
    # @return [String] actual osu!skin directory
    # @raise [Error::SkinNotFoundError] if +skin.ini+ is not found until root
    #   directory.
    def skin_dir
      return @skin_dir if @skin_dir
      # Ascends directory to check until reaches root.
      no_result = false
      @skin_dir = @base_dir
      loop do
        $stderr.puts "Scanning on #{@skin_dir}"
        break if File.exist?(skin_file)
        next_dir = File.expand_path("..", @skin_dir)
        if next_dir == @skin_dir then
          no_result = true
          break
        else
          @skin_dir = next_dir
        end
      end

      if no_result then
        @skin_dir = nil
        fail Error::SkinNotFoundError, "Cannot find skin.ini"
      else
        @skin_dir
      end
    end
    # Obtain currently read skin file from +skin.ini+
    # @!attribute [r] skin_file
    # @return [String]
    def skin_file
      return unless @skin_dir
      File.join(@skin_dir, FILE_NAME)
    end
    # Parse +skin.ini+ file into program readable object.
    # @return [void]
    def read_file
      @skin_data = OsuRuby::Parser::FileData.load(File.read(skin_file))
      @skin_data
    end
    # Write skin data to respective +skin.ini+
    # @return [void]
    def write_file
      @skin_data.write skin_file
    end
  end
end
