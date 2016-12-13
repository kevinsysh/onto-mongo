# https://robots.thoughtbot.com/writing-a-domain-specific-language-in-ruby

module OntoMap

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    attr_accessor :mapping, :ontology_class, :onto_query

    def ontoclass(ontology_class)
      @ontology_class = ontology_class
    end

    def maps(attributes)
      relation = attributes[:from]
      property = attributes[:to]

      @mapping ||= {}
      @mapping[relation] = property
    end

    # TODO refactor...
    def query(sparql)
      @onto_query = OntoQuery.new(sparql)
      model = Researcher # TODO
      parameters = []

      triples = onto_query.triples
      relations = extract_relations(triples, model)
      # variables are not relations (inverse of relations)
      variables = extract_variables(triples, model)

      if relations.present?
        first_projection = {
          "$project": {
            "name": true #TODO de onde vem esse name?
          }
        }
        relations.each do |triple|
          var = { triple.object.name.to_s => "$" + prop(triple).to_s }
          first_projection[:$project].merge!(var)
        end

        unwinds = relations.map do |triple|
          { "$unwind": "$" + triple.object.name.to_s }
        end

        parameters << first_projection
        parameters << unwinds
      end

      # TODO de onde vem esse name?
      second_projection = {
        "$project": {
          "name": true
        }
      }

      # include filters in projection
      filtered_variables = onto_query.filter.values.uniq.flatten(1)
      if filtered_variables.present?

        equality_filters = []
        inequality_filters = []

        filtered_variables.each do |f|
          var = { f => true }
          second_projection[:$project].merge!(var)
        end

        # TODO this might be wrong
        # repeated variables indicate equality of attributes
        equality_filters = variables.
                            group_by{|triple| triple.object.name }.
                            select{|object, group| group.size > 1 }.
                            map{|object, group|
                              group.map{|repeated_var|
                                "$#{repeated_var.subject.name}.#{object}"
                              }
                            }.flatten(1)

        # TODO Should we treat other cases, like >= ?
        if onto_query.filter[:ne].present? && equality_filters.present?
          inequality_filters = variables.
                               select{|triple|
                                 filtered_variables.include?(triple.subject.name)
                              }.
                              map{|triple|
                                property = prop(triple)
                                "$#{triple.subject.name}.#{property}"
                              }

          # we filter everything that should be different
          # except the things that should be equal.
          # ne_filter = not_equal_properties EXCEPT equal_properties
          inequality_filters = inequality_filters - equality_filters
        end


        filters = []
        filters << { "$eq": equality_filters   } if equality_filters.present?
        filters << { "$ne": inequality_filters } if inequality_filters.present?

        if filters.size > 1
          filters = {"$and" => filters}
        end

        if filters.present?
          filter_key = "filter_1"
          second_projection[:$project].merge!({ filter_key => filters })

          parameters << second_projection

          # match
          match = {
            "$match": {
              filter_key => true
            }
          }

          parameters << match
        end
      end

      # TODO output_projection
      # 1. pegar as variaveis de output de onto_query.project
      # 2. dar algum match com as vars?
      output_projection = {
        "$project": {
        }
      }

      onto_query.project.each do |output_var|
        attribute = '$'

        triple = variables.select{|triple| triple.object.name == output_var }.first
        property = prop(triple)

        # TODO: this might be wrong...
        complex = relations.select{|rel| triple.subject.name == rel.object.name }.first
        if complex.present?
          attribute << complex.object.name.to_s + '.'
        end

        attribute << property.to_s
        var = { triple.object.name.to_s => attribute }

        output_projection[:$project].merge!(var)
      end

      parameters << output_projection

      # TODO refactor parameters...
      # parameters2 = [first_projection, unwinds, second_projection, match, output_projection].flatten(1)
      final_parameters = parameters.flatten(1)
      Researcher.collection.aggregate(final_parameters)
    end


=begin
    def query(sparql)
      triples = expand_query(sparql)
      model = nil

      # TODO
      # descobrir qual é a model: quem for da ontoclass foaf:Person
      # vamos supor que seja sempre Researcher no momento (TODO)
      #if triples :ontoclass ... == 'foaf:Person'
        model = Researcher
      #end

      filters = triples.map{|triple|
        property = @mapping[triple.predicate]
        value = triple.object
        { property => value }
      }.inject({}){|hash, injected| hash.merge!(injected)}

      puts filters.to_yaml
      model.where(filters)
    end
=end

    def print
      puts "Ontoclass: #{@ontology_class}"
      puts "Mapping: #{@mapping.to_s}"
    end

    private

      def extract_relations(triples, klass)
        triples.select{|triple|
          property = prop(triple)
          is_relation(klass, property)
        }
      end

      # variables are not relations
      # (inverse of relations)
      def extract_variables(triples, klass)
        triples.reject{|triple|
          property = prop(triple)
          is_relation(klass, property)
        }
      end

      def is_relation(klass, property)
        klass.relations? && klass.relations[property.to_s].present?
      end

      def prop(triple)
        predicate = triple.predicate
        property = mapping[predicate.to_s]
        if property.present?
          return property
        else
          # try to find property on relations
          self.relations.values.
          select{|rel|
            rel.klass.mapping.present? && rel.klass.mapping[predicate.to_s].present?
          }.
          map{|rel|
            rel.klass.mapping[predicate.to_s].to_s
          }.first
        end
      end
=begin
      def expand_query(sparql)
        OntoSplit.split(sparql)
      end

      def build_query(triples)
        subjects = Hash.new
        triples.each do |t|
          if !subjects.key? t.subject
            subjects[t.subject] = Subject.new(t.subject)
          end
          subjects[t.subject].add_relation(t.predicate, t.object)
        end

        return subjects
      end

      def build_query(arr)
        # TODO
        # query.inject  ... montar um hash de subjects com suas listas de relações/properties
        # por exemplo:
        # ?person -> [a: "foaf:Person", "foaf:name" = "fulano", "foaf:mbox" = "123@4"]
        # pode ser um objeto tbm... fica mais facil.
      end
=end

  end
end
