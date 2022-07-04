module OsuRuby
  module Parser
    # base-class for parsing  human editable text-file
    # related to osu! content.
    class Base
      # @return [::IO] underlying IO used for reading
      attr_reader :io
      
      # @param io [::IO] an IO object to read from.
      def initialize(io)
        @io = io
      end
      # parse given IO input to program editable contents
      # @return [void]
      def parse
      end
      private
      # @!visibility public
      # compiles editable contents into an osu!-supported strings.
      # @return [String]
      def compile_contents
      end
      # @overload write(fn)
      #   Writes parsed content to a file with given +filename+
      #   @param fn [String] filename of target file
      # @overload write(io)
      #   writes parsed content to an IO object.
      #   @param io [#write] write-supported IO object
      # @return [Void]
      public
      def write(file)
        case file
        when ::IO
          file.write(compile_contents)
        when String
          File.write(file, compile_contents)
        end
        nil
      end
      class << self
        # parse file from given filename
        # @note All IO variables retrieved from this method always
        #   closed after parsing.
        # @param fn [String] filename to read
        # @return [Base]
        def load(fn)
          io = File.open(fn, 'r')
          parser = new(io)
          parser.parse
          parser
        ensure
          io.close
        end
      end
    end
  end
end
