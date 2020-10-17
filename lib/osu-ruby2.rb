module OsuRuby
  BASE_MDOES = %i(osu taiko fruits mania).freeze
  class << self
    private
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
    def barename(file)
      File.basename(file,File.extname(file))
    end
    def require_ns
      file = caller_locations.first.path
      safe_glob(File.join(__dir__,barename(__FILE__),barename(file)),'*.rb') do |fn| require fn end
    end
  end
end
