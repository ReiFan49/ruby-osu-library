module OsuRuby
  require_relative 'multiplexer_interface'
  module Interface
    module ExtendableMethod
      module I
        def process_extensions
          self.class.extensions.each do |m|
            next if m == __meth__
            next unless respond_to?(m,true)
            send(m)
          end
        end
      end
      module X
        def extensions
          (self.superclass < ExtendableMethod ? self.superclass.extensions : []) | @_extensions
        end
        def extension_add(meth,at=nil)
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
        def extension_remove(meth)
          @_extensions.delete(meth)
          true
        end
        def extension_pos(meth)
          @_extensions.index(meth)
        end
      end
      extend MultiplexerInterface
    end
  end
end
