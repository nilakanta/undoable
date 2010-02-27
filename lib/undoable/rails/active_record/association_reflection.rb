module Undoable::Rails::ActiveRecord
  module AssociationReflection

    def restore_association(record, attributes)
      if(macro == :has_one && !options[:through])
        restore_associated_record(record.send("build_#{self.name}", attributes), attributes)
      elsif(macro == :has_many && !options[:through])
        if attributes.kind_of? Array
          record.send(self.name).clear
          attributes.each {|association_attributes| restore_association(record, association_attributes) }
        else
          has_many_association = record.send(self.name)
          restore_associated_record(has_many_association.build, attributes) if has_many_association 
        end
      elsif((macro == :has_and_belongs_to_many))
        record.send("#{self.name}=", klass.find(attributes))
      end
    end
    
    def serialize_association(record, attrs, already_serialized)
      if self.macro == :has_one
        associated = record.send(self.name)
        attrs[self.name] = associated ? Undoable::Models::Serialize::serialize_attributes(associated, already_serialized) : nil
      elsif self.macro == :has_many and !self.options[:through]
        attrs[self.name] = record.send(self.name).collect{|r| Undoable::Models::Serialize::serialize_attributes(r, already_serialized)}
      elsif (self.macro == :has_and_belongs_to_many || (self.macro == :has_many && self.options[:through]))
        attrs[self.name] = record.send("#{self.name.to_s.singularize}_ids".to_sym)
      end
    end
    
    def restore_associated_record(associated_record, attributes)
      return unless attributes && associated_record
      associated_record.id = attributes['id']
      attrs, association_attrs = Undoable::Models::Reflection::attributes_and_associations(associated_record.class, attributes)
      associated_record.instance_variable_set(:@new_record, nil) if associated_record.class.exists?(associated_record.id)
      associated_record.update_attributes(attrs)
      association_attrs.each_pair { |key, values| restore_association(associated_record, key, values) }
    end
  end
end
