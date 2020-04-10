class Subject
  attr_accessor :subject
  attr_accessor :ontoclass
  attr_accessor :name

  def initialize(subject)
    @subject = subject
    @relations = []
    puts 's-----------------------------------'
    puts @subject.class
    puts subject.class
    puts @subject.to_s
    if self.is_variable?
      @name = @subject.to_s.split('?')[1]
    else
      @name = @subject
    end
  end

  def add_relation(property, object)
    @relations << {property: property, object: object}
  end

  def var_name
    return @subject
  end

  def is_variable?
    return @subject.to_s[0].eql?("?")
  end

  def raw_ontoclass
    return @ontoclass.to_s.split('#')[1]
  end
end
