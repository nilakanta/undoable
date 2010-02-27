module Undoable
  module Models
    class UndoTransaction < ActiveRecord::Base
      has_many :undo_records, :dependent => :destroy, :class_name => '::Undoable::Models::UndoRecord'

      def undo
        ActiveRecord::Base.undo_transaction = nil
        undo_records.reverse_each { |undo_record| undo_record.undo }
      end

      def to_xml(options = {})
        super(options.merge(:root => self.class.name.demodulize.underscore))
      end
    end
  end
end