module Undoable::Models
  module Reverse
    def self.included(receiver)
      receiver.send :include, InstanceMethods
      receiver.extend ClassMethods

      receiver.after_create :create_undo_for_create
      receiver.before_update :create_undo_for_update
      receiver.before_destroy :create_undo_for_destroy

      receiver.metaclass.alias_method_chain :collection_accessor_methods, :undo_transaction
      receiver.metaclass.alias_method_chain :delete_all, :undo_transaction
      receiver.metaclass.alias_method_chain :update_all, :undo_transaction
    end

    module InstanceMethods
      def create_undo_for_create
        self.class.send(:create_undo_records, 'Create', self)
      end

      def create_undo_for_update
        self.class.send(:create_undo_records, 'Update', self)
      end

      def create_undo_for_destroy        
        self.class.send(:create_undo_records, 'Destroy', self)
      end

      def move_to_with_undo_transaction(target, position)
        self.class.send(:create_undo_records, Update.to_s.demodulize, self) if self.respond_to? :create_undo_for_update
        move_to_without_undo_transaction(target, position)
      end
    end

    module ClassMethods
      private
      def collection_accessor_methods_with_undo_transaction(reflection, association_proxy_class, writer = true)
        collection_accessor_methods_without_undo_transaction(reflection, association_proxy_class, writer)

        unless (association_proxy_class == ActiveRecord::Associations::HasManyThroughAssociation ||
          method_defined?("#{reflection.name}_with_undo_transaction=".to_sym))
          define_method("#{reflection.name}_with_undo_transaction=".to_sym) do |new_value|
            self.class.send(:create_undo_records, 'Update', self) unless self.new_record?
            send("#{reflection.name}_without_undo_transaction=".to_sym, new_value)
          end

          send(:alias_method_chain, "#{reflection.name}=", :undo_transaction)
        end
      end

      def delete_all_with_undo_transaction(conditions = nil)
        create_all_undo_records('Destroy', conditions)
        delete_all_without_undo_transaction(conditions)
      end

      def update_all_with_undo_transaction(updates, conditions = nil, options={})
        create_all_undo_records('Update', conditions)
        update_all_without_undo_transaction(updates, conditions, options)
      end

      def create_all_undo_records(operation, conditions)
        return unless ActiveRecord::Base.undo_transaction
        transaction = load_undo_transaction
        records = self.find(:all, :conditions => conditions)
        records.each { |record| transaction.undo_records << UndoRecord.new(operation, record) }
      end
      
      def create_undo_records(operation, undoable_record)
        return unless (ActiveRecord::Base.undo_transaction && undoable_record.errors.empty?)
        transaction = send(:load_undo_transaction)
        transaction.undo_records << UndoRecord.new(operation, find(undoable_record.id))
      end

      def load_undo_transaction
        UndoTransaction.find(ActiveRecord::Base.undo_transaction)
      end
    end
  end
end