# https://robots.thoughtbot.com/writing-a-domain-specific-language-in-ruby

module OntoMap
  attr_accessor :mapping, :ontology_class

  @mapping = {}
  @ontology_class = nil

=begin

  @attributes = {}

  def method_missing(name, *args)
    attribute = name.to_s
    if attribute =~ /=$/
      @attributes[attribute.chop] = args[0]
    elsif @attributes[attribute].present?
      @attributes[attribute]
    else
      self.send @mapping[attribute]
    else

    end
    puts attribute
  end
=end

  def ontoclass(ontology_class)
    @ontology_class = ontology_class
  end

  def maps(relation, property)
    @mapping ||= {}
    @mapping[relation] = property
  end

  def query(sparql)
    expanded_query = expand_query(sparql)
    query = build_query(expanded_query)
    model = nil
    result = []

    # descobrir qual é a model: quem for da ontoclass foaf:Person
    # vamos supor que seja sempre CV no momento (TODO)
    if query[:ontoclass] == 'foaf:Person'
      model = CV
      # TODO filter...
      result = model.all
    end

    query[:relations].each do |relation|
      # where :name == fulano, etc.
      prop = relation[:property]
      property = @mapping[prop]
      value = relation[:object]

      puts "prop = #{prop}, #{property} == #{value}"


      # TODO filter...
      result = result.to_a.select{|cv|
        cv.send(property) == value
      }
    end
    result
  end

  def expand_query(sparql)
    # TODO montar uma estrutura +- como essa a partir do sparql
    # exemplo:
    
    OntoSplit.split(sparql)
    # [{ subject: "?person", property: :a, object: 'foaf:Person'     },
    #  { subject: "?person", property: "foaf:name", object: 'Wagner da Silva' },
    #  { subject: "?person", property: "foaf:mbox", object: 'teste@gmail.com' }]
  end

  def build_query(arr)
    # TODO
    # query.inject  ... montar um hash de subjects com suas listas de relações/properties
    # por exemplo:
    # ?person -> [a: "foaf:Person", "foaf:name" = "fulano", "foaf:mbox" = "123@4"]
    # pode ser um objeto tbm... fica mais facil.

    {
      subject: '?person',
      ontoclass: 'foaf:Person',
      relations: [{ property: "foaf:name", object: 'Wagner da Silva' }]
    }
  end

  def print
    puts "Ontoclass: #{@ontology_class}"
    puts "Mapping: #{@mapping.to_s}"
  end
end