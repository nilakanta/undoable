module Undoable
  ActiveRecord::Base.send(:include, ::Undoable::Rails::ActiveRecord::Base)
  ActiveRecord::Associations::AssociationCollection.send(:include, ::Undoable::Rails::ActiveRecord::AssociationCollection) 
  ActiveRecord::Reflection::AssociationReflection.send(:include, ::Undoable::Rails::ActiveRecord::AssociationReflection) 
end
