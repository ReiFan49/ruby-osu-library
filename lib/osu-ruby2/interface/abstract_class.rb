module OsuRuby
  module Error
    # Abstract class instantiation error.
    class AbstractClassError < StandardError; end
    # Abstract method call error
    class AbstractMethodError < NotImplementedError; end
  end
  require_relative 'multiplexer_interface'
  module Interface
    # defines simple abstract class system
    module AbstractClass
      # auto include methods defined in here
      module I
        # defines an abstract constructor
        def initialize(*)
          fail Error::AbstractClassError, "#{self.class.name} is abstract" if self.class.abstract?
          super() unless method(__method__).super_method.owner == BasicObject
        end
      end
      # auto extend methods defined in here
      module X
        # checks abstractness of a class
        # @return [Boolean]
        def abstract?; @abstract; end
        # specify a class as abstract
        # @return [void]
        def abstract!; @abstract = true; end
        # defines an abstract method (NotImplementedError)
        # @return [Symbol]
        def abstract_method(method)
          define_method method do |*|
            fail Error::AbstractMethodError, "please define this"
          end
        end
        # allows class to have it's abstractness checked.
        # @return [void]
        def self.extended(cls)
          cls.instance_variable_set(:@abstract,false)
        end
      end
      extend MultiplexerInterface
    end
  end
end
