require File.dirname(__FILE__) + '/../../spec_helper'

class Company < ActiveRecord::Base; end
class Firm < Company; end
class Client < Company; end

module Undoable
  module Models
    module STIRelation
      describe "STI" do
        before :all do
          connection = ActiveRecord::Base.connection
          begin
            connection.create_table "companies", :force => true do |t|
              t.string :name
              t.string :type
              t.timestamps
            end
          rescue
            p "Error Unable to create test tables"
          end
        end

        before :each do
          @undo_transaction = UndoTransaction.create!
          set_undo_transaction_to_nil
        end

        describe "Undo creation" do
          it "should remove the sti models" do
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            firm = Firm.create!(:name => 'firm')
            client = Client.create!(:name => 'client')
            
            UndoTransaction.find(@undo_transaction.id).undo
            Firm.find(:all).should be_empty
            Client.find(:all).should be_empty
          end
        end

        after :each do
          delete_all_records([UndoTransaction, UndoRecord, Company])
          set_undo_transaction_to_nil
        end

        after :all do
          connection = ActiveRecord::Base::connection
          begin
            connection.drop_table "companies"
          rescue
            p "Unable to drop tables"
          end
        end
      end
    end
  end
end
