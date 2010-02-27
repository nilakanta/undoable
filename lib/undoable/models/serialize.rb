module Undoable::Models
  module Serialize
    def self.serialize_attributes(record, already_serialized = {})
      return if already_serialized["#{record.class}.#{record.id}"]

      original_attributes = record.attributes unless (record.kind_of?(Hash))
      already_serialized["#{record.class}.#{record.id}"] = true

      serialize_association(record, original_attributes.dup, already_serialized)
    end

    def self.serialize_association(record, attrs, already_serialized)
      record.class.reflections.values.each { |association| association.serialize_association(record, attrs, already_serialized) }
      attrs
    end
  end
end
