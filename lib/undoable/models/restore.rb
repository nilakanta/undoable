module Undoable::Models
  module Restore

    def self.restore(undo_record, update=true)
      attrs, association_attrs = undo_record.revision_attributes_and_associations
      record = undo_record.restore_class.new

      record.instance_variable_set(:@new_record, nil) if (update)
      record.instance_eval { def set_default_left_and_right; end } if record.respond_to?(:set_default_left_and_right)
      attrs.each_pair { |key, value| record.write_attribute(key, value) }

      association_attrs.each_pair { |association, attribute_values| restore_association(record, association, attribute_values) }
      return record
    end

    def self.restore_association(record, association, attributes)
      reflection = record.class.reflections[association]
      reflection.restore_association(record, attributes)
    end
  end
end
