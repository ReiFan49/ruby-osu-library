module OsuRuby
  require_relative 'multiplexer_interface'
  module Interface
    # interface to let osu! objects easily extendable by plugins
    module ExtendableMethod
      # auto include methods defined in here
      module I
        # process all class etensions
        # @return [void]
        def process_extensions
          self.class.extensions.each do |m|
            next if m == __meth__
            next unless respond_to?(m,true)
            send(m)
          end
        end
      end
      # auto extend methods defined in here
      module X
        # obtain list of extensions defined for the class
        # @return [Array<Symbol>] list of extensions defined as symbol.
        def extensions
          (self.superclass < ExtendableMethod ? self.superclass.extensions : []) | @_extensions
        end
        # @overload extension_add(meth)
        #   appends extension to the queue
        #   @param meth [Symbol] extension symbol to add
        #   @return [void]
        # @overload extension_add(meth, at)
        #   inserts extension at given position
        #   @param meth [Symbol] extension symbol to add
        #   @param at [Integer] position to insert the extension on.
        #     must be a non-negative integer bounded by the length of extension.
        #     any errors will assume the precedent form instead.
        #   @return [void]
        def extension_add(meth, at=nil)
          if String === meth then
            meth = meth.to_sym
          end
          case at
          when 0...(@extensions.length)
            @_extensions.insert(at,meth)
          else
            @_extensions.push(meth)
          end
          true
        end
        # removes defined extension.
        # @param meth [Symbol] extension name to remove
        # @return [void]
        def extension_remove(meth)
          @_extensions.delete(meth)
          true
        end
        # checks extension execution order.
        # @param meth [Symbol] extension to check
        # @return [Integer, nil] current extension execution order
        def extension_pos(meth)
          @_extensions.index(meth)
        end
      end
      extend MultiplexerInterface
    end
  end
end
