module OsuRuby
  module Parser
    # Base-class for parsing human editable text-file
    # related to osu! content.
    #
    # Parser Sekelton uses 3 functionality to work.
    #
    # * *Reader*, text file to machine variables conversion. Uses {Section} and {Entry} to help.
    # * *Writer*, machine variables to text file. Make a use of {Base#compile_contents} and {Section#to_s}.
    # * *Converter*, passes machine variables into Behavior specific container that accepts given variables. See {#convert}
    #
    # These functionality defines on how parser works in general and will be implemented in detail by its subclasses.
    class Base
      def initialize
      end
      # @abstract parse given IO input to program editable contents
      # @param io [#read] Readable IO stream to parse
      # @return [void]
      def parse(io)
      end
      # @overload write(fn)
      #   Writes parsed content to a file with given +filename+
      #   @param fn [String] filename of target file
      # @overload write(io)
      #   writes parsed content to an IO object.
      #   @param io [#write] Writable IO object
      # @see #compile_contents
      # @return [void]
      def write(file)
        case file
        when ::IO
          file.write(compile_contents)
        when String
          File.write(file, compile_contents)
        end
        nil
      end
      # @abstract This is only to document how +convert+ function expected to work.
      #   Further implementations are handled by its subclasses.
      # @overload convert
      #   create new object using given parsed structure data.
      # @overload convert(obj)
      #   @param obj [Object] Object-class descendant to have its internal overwritten with given structure data.
      # @return [Object]
      def convert(obj = nil)
      end
      private
      # @!visibility public
      # @private
      # @abstract Section compilation implmenetations are handled by subclasses.
      # compiles editable contents into an osu!-supported strings.
      # @return [String]
      def compile_contents
      end
      
      class << self
        # parse file from given filename
        # @note All IO variables retrieved from this method always
        #   closed after parsing.
        # @param fn [String] filename to read
        # @return [Base]
        def load(fn)
          io = File.open(fn, 'r')
          parser = new
          parser.parse(io)
          parser
        ensure
          io.close
        end
      end
    end
  end
end
