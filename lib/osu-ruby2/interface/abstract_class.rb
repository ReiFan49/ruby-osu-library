module OsuRuby
  module Errors
    class AbstractClassError < StandardError
    end
    class AbstractMethodError < NotImplementedError
    end
  end
  require_relative 'multiplexer_interface'
  module Interface
    # defines simple abstract class system
    module AbstractClass
      module I
        # defines an abstract constructor
        def initialize(*)
          fail Errors::AbstractClassError, "#{self.class.name} is abstract" if self.class.abstract?
          super() unless method(__method__).super_method.owner == BasicObject
        end
      end
      module X
        # checks abstractness of a class
        def abstract?; @abstract; end
        # specify a class as abstract
        def abstract!; @abstract = true; end
        # defines an abstract method (NotImplementedError)
        def abstract_method(method)
          define_method method do |*|
            raise Errors::AbstractMethodError, "please define this"
          end
        end
        def self.extended(cls)
          cls.instance_variable_set(:@abstract,false)
        end
      end
      extend MultiplexerInterface
    end
  end
end
