module OsuRuby
  BASE_MODES = %i(osu taiko fruits mania).freeze
  class << self
    private
    # INTERNAL: a safer glob operation that escapes meta-characters on directory
    def safe_glob(dir,*args,**kwargs,&block)
      gsub_regx = %r([*?\[\]\{\}?\\])
      pattern = File.join(
        dir.gsub(gsub_regx){|pattr|"\\#{pattr}"},
        args[0]
      )
      args[0] = pattern
      
      if kwargs.empty? then
        Dir.glob(*args,&block)
      else
        Dir.glob(*args,**kwargs,&block)
      end
    end
    # INTERNAL: extracts a file barename (no directory and no extension)
    # @param file [String]
    # @return [String] a bare filename
    def barename(file)
      File.basename(file,File.extname(file))
    end
    # INTERNAL: require respective namespace from point of call
    def require_ns
      file = caller_locations.first.path
      safe_glob(File.join(__dir__,barename(__FILE__),barename(file)),'*.rb') do |fn| require fn end
    end
  end
end
require 'osu-ruby2/version'
