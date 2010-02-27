module Undoable::Models
  class Operation    
    def initialize(undo_record)
      @undo_record = undo_record
    end

    protected
    def un_create
      record = @undo_record.restore_class.destroy(@undo_record.undoable_id)
    end

    def un_destroy
      Restore::restore(@undo_record, false).save!
    end      
  end
end
