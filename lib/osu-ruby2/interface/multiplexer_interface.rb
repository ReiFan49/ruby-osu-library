module OsuRuby
  module Interface
    module MultiplexerInterface
      # upon extended to an interface, the interface perform following actions
      #   when included:
      #
      # * include any methods from +I+ class.
      # * extend any methods from +X+ class.
      #
      # this allows module inclusion to be more cleaner like
      # @see Rails' Concerns
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
    # @!visibility public
    # @api private
    # interface that defines instantenous include and extend upon +include+.
    module MultiplexerInterface; end
  end
end
