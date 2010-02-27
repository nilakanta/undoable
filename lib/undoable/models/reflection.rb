module Undoable::Models
  module Reflection

    def self.attributes_and_associations(klass, hash)
      attrs = {}
      association_attrs = {}

      hash.each_pair do |key, value|
        klass.reflections.has_key?(key) ? association_attrs[key] = value : attrs[key] = value
      end

      [attrs, association_attrs]
    end
  end
end
