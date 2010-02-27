module Undoable
  module Models
    class UndoRecord < ActiveRecord::Base

      belongs_to :undo_transaction, :class_name => '::Undoable::Models::UndoTransaction'
      before_create :set_revision_number

      def initialize(operation, record)
        super()
        self.undoable_type = record.class.name
        self.undoable_id = record.id
        self.data = Marshal.dump(Undoable::Models::Serialize::serialize_attributes(record))
        self.operation = operation
      end
             
      def restore_class
        undoable_type.constantize
      end                                        
      
      def revision_attributes
        Marshal.load(self.data)
      end
                           
      def revision_attributes_and_associations
        Reflection::attributes_and_associations(restore_class, revision_attributes)
      end
      
      def inspect
        "\#<#{self.class} id=#{id} operation=#{operation} undo_transaction_id=#{undo_transaction_id} \
        \undoable_type=#{undoable_type} undoable_id=#{undoable_id} revision=#{revision} attributes=#{revision_attributes.inspect}>"
      end

      def self.find_revision(klass, id, revision)
        find(:first, :conditions => {:undoable_type => klass.to_s, :undoable_id => id, :revision => revision})
      end

      def self.truncate_revisions(undoable_type, undoable_id, options)
        return unless options[:limit] or options[:minimum_age]

        conditions = ['undoable_type = ? AND undoable_id = ?', undoable_type.to_s, undoable_id]
        if options[:minimum_age]
          conditions.first << ' AND created_at <= ?'
          conditions << options[:minimum_age].ago
        end

        start_deleting_revision = find(:first, :conditions => conditions, :order => 'revision DESC', :offset => options[:limit])
        if start_deleting_revision
          delete_all(['undoable_type = ? AND undoable_id = ? AND revision <= ?', undoable_type.to_s, undoable_id, start_deleting_revision.revision])
        end
      end

      def undo
        operation_instance.undo
      end

      private
      def operation_instance
        "::Undoable::Models::#{operation}".constantize.new(self)
      end

      def set_revision_number
        unless self.revision
          last_revision = self.class.maximum(:revision, :conditions => {:undoable_type => self.undoable_type, :undoable_id => self.undoable_id}) || 0
          self.revision = last_revision + 1
        end
      end
    end
  end
end
