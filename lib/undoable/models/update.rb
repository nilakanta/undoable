module Undoable::Models

  class Update < Operation
    def undo
      undo_update
    end

    private
    def undo_update
      previous = UndoRecord.find(:first, {:conditions => ['undoable_type = ? AND undoable_id = ? AND revision = ?', 
                                          @undo_record.undoable_type.to_s, @undo_record.undoable_id, @undo_record.revision]})
      Restore::restore(previous, true).save!
    end
  end
end