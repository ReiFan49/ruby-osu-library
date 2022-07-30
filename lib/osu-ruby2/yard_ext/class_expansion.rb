module OsuRuby::YARDExt
  # @see https://github.com/lsegal/yard/blob/main/lib/yard/handlers/ruby/class_handler.rb
  class ClassExpansion < YARD::Handlers::Ruby::Base
    handles :class, :assign
    namespace_only
    
    process do
      meth_name = "process_statement_#{statement.type}"
      send(meth_name, statement) if respond_to? meth_name, true
    end
    
    private
    def process_statement_class(statement)
      classname = statement[0].source.gsub(/\s/, '')
      superclass = parse_superclass(statement[1])
      # puts sprintf("%s %s %p", 'ClsEXP1', classname, statement[1])
    end
    
    def process_statement_assign(statement)
      if statement[1].call? && statement[1][2] == s(:ident, "create") then
        class_name = statement[0][0].source
        superclass_name = statement[1][0].source
        entryclass_name = statement[1][3][0][0].source
        return unless superclass_name.end_with?('Section') &&
          entryclass_name.end_with?('Entry')
        cls = create_class(class_name, superclass_name)
        parse_block(statement[1].block[1], namespace: cls) unless statement[1].block.nil?
      else
        # pass
      end
    end
    
    def parse_superclass(superclass)
    end
    
    def create_class(classname, superclass)
      register YARD::CodeObjects::ClassObject.new(namespace, classname) do |o|
        o.superclass = superclass if superclass
        o.superclass.type = :class if o.superclass.is_a?(Proxy)
      end
    end
  end
  ::YARD::Handlers::Ruby::ConstantHandler.process do
    super()
  rescue YARD::Parser::UndocumentableError
  end
end if defined?(YARD)
