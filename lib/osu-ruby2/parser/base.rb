module OsuRuby
  module Parser
    class Base
      attr_reader :io
      def initialize(io)
        @io = io
      end
      def parse
      end
      def process
        parse
      end
    end
    class TextParser < Base
    end
  end
end
