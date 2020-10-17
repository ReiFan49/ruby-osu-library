require 'osu-ruby2'
module OsuRuby::Skin
  class Processor
    FILE_NAME = 'skin.ini'
    def initialize(base_dir)
      @base_dir  = Dir.pwd || base_dir
      @skin_data = nil
    end
    def parse
      skin_dir
      read_file
    end
    def skin_dir
      return @skin_dir if @skin_dir
      no_result = false
      @skin_dir = @base_dir
      loop do
        $stderr.puts "Scanning on #{@skin_dir}"
        break if File.exist?(File.join(@skin_dir,FILE_NAME))
        next_dir = File.expand_path("..",@skin_dir)
        if next_dir == @skin_dir then
          no_result = true
          break
        else
          @skin_dir = next_dir
        end
      end

      if no_result then
        fail "Cannot find skin.ini"
      else
        @skin_dir
      end
    end
    def read_file
      @skin_data = OsuRuby::FileData.new(File.read(File.join(@skin_dir,FILE_NAME)))
      @skin_data.process
    end
  end
end
