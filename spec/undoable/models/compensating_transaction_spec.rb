require File.dirname(__FILE__) + '/../../spec_helper'

module Undoable
  module Models
    describe UndoTransaction do
      it "should also destroy all the undo records" do
        undo_transaction = UndoTransaction.create
        undo_transaction.should_receive(:undo_records).and_return([stub("record1", :destroy => {}), stub("record2", :destroy => {})])
        undo_transaction.destroy
      end

      it "should call undo on each undo_records" do
        undo_transaction = UndoTransaction.new
        undo_transaction.should_receive(:undo_records).and_return([stub("record1", :undo => {}), stub("record2", :undo => {})])
        undo_transaction.undo
      end

      describe "xml serialisation" do
        it "should include undo-action as the root tag" do
          Hash.from_xml(UndoTransaction.create!.to_xml)["undo_transaction"].should_not be_nil
        end
      end
      
      after :each do
        UndoTransaction.delete_all
      end
    end
  end
end