module OsuRuby
  module Interface
    module MultiplexerInterface
      def self.extended(cls)
        cls.send :private_constant, :I
        cls.send :private_constant, :X
        cls.class_exec do
          define_singleton_method :included do |other|
            other.include cls.const_get(:I)
            other.extend cls.const_get(:X)
          end
        end
      end
    end
    private_constant :MultiplexerInterface
  end
end
