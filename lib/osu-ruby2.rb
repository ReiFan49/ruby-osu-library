# Base definition of the library.
# From now on the osu-ruby library will refer this namespace as opposed to clutterful V1 definition
#
# DEV NOTE: Modules may implicitly invokes the internal methods from here.
module OsuRuby
  BASE_MODES = %i(osu taiko fruits mania).freeze
  OSU_ENV_FILE = '.osu-env'.freeze
  private_constant :OSU_ENV_FILE
  @env = {}
  # @api private
  class << self
    # @return [Hash] current osu! environment
    def env
      {}.update(@env).update(Thread.current[:osu_env] || {})
    end
    private
    # @!visibility public
    # This is a quick .env read, does *not* comform the original spec or whatsoever.
    def load_env
      @env.clear
      dirs = []
      add_dir = ->(dir){
        dirs.push File.expand_path(File.join('.',OSU_ENV_FILE), dir)
      }
      [Dir.pwd].each do |preserved_dir|
        add_dir.call(preserved_dir)
        add_dir.call(File.join('..',preserved_dir))
      end
      # If somewhere inside home directory
      # recusrively add the tree
      if Dir.pwd.start_with?(ENV['HOME'])
        cd = File.expand_path('../..',Dir.pwd)
        while cd != ENV['HOME'] && cd.start_with?(ENV['HOME'])
          add_dir.call(cd)
          cd = File.expand_path('..',cd)
        end
      end
      # add user home and gem directory
      [ENV['HOME'], __dir__].each do |preserved_dir|
        add_dir.call(preserved_dir)
      end
      dirs.uniq!
      dirs.each do |env_dir|
        next unless File.exists?(env_dir)
        File.readlines(env_dir).each do |env_line|
          env_line.chomp!
          match = /^([A-Za-z][A-Za-z0-9_]+)\s*[=]\s*(\w*)$/.match(env_line)
          next if match.nil?
          value = match[2]
          case match[2]
          when /^\d+$/; value = value.to_i
          when /^\d+[.]\d+$/; value = value.to_f
          when /^true|false$/; value = value == true
          end
          @env.store(match[1].to_sym, value)
        end
        break
      end
      env
    end
    # @!visibility public
    # a safer glob operation that escapes meta-characters on directory
    # @note All the values are pure proxy of Dir#glob
    # @param dir [String] cue directory to start glob on (allows glob escape handle)
    def safe_glob(dir,*args,**kwargs,&block)
      gsub_regx = %r([*?\[\]\{\}?\\])
      pattern = File.join(
        dir.gsub(gsub_regx){|pattr|"\\#{pattr}"},
        args[0],
      )
      args[0] = pattern
      
      if kwargs.empty? then
        Dir.glob(*args,&block)
      else
        Dir.glob(*args,**kwargs,&block)
      end
    end
    # @!visibility protected
    # extracts a file barename (no directory and no extension)
    # @param file [String] filename to filter
    # @return [String] a bare filename
    def barename(file)
      File.basename(file,File.extname(file))
    end
    # @!visibility protected
    # require respective namespace from point of call
    # @return [void]
    def require_ns
      file = caller_locations.first.path
      safe_glob(File.join(__dir__,barename(__FILE__),barename(file)),'*.rb') do |fn| require fn end
    end
  end
  load_env
end
require 'osu-ruby2/version'
require 'osu-ruby2/constants'
require 'osu-ruby2/interface'
require 'osu-ruby2/yard_ext'
