require File.dirname(__FILE__) + '/../../spec_helper'

class Assembly < ActiveRecord::Base
  has_and_belongs_to_many :parts
  validates_presence_of :name
end

class Part < ActiveRecord::Base
  has_and_belongs_to_many :assemblies
  validates_presence_of :name
end

module Undoable
  module Models
    describe "Has and belongs to many" do

      before(:all) do
        connection = setup_db_connection
        setup_db_tables connection
        begin
          connection.create_table "assemblies", :force => true do |t|
            t.string :name
            t.timestamps
          end

          connection.create_table "parts", :force => true do |t|
            t.string :name
            t.timestamps
          end

          connection.create_table "assemblies_parts", :force => true, :id => false do |t|
            t.integer :assembly_id
            t.integer :part_id
            t.timestamps
          end
        rescue
          p "Error Unable to create test tables"
        end
      end

      before(:each) do
        @undo_transaction = UndoTransaction.create!
        set_undo_transaction_to_nil
      end

      describe "Undo creation" do
        it "should undo the creation of part and its association when the transaction is rolled back" do
          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          assembly = Assembly.create!(:name => 'assembly')
          part = Part.create!(:name => 'part')
          part.assemblies << assembly

          assembly.parts.should == [part]
          UndoTransaction.find(@undo_transaction.id).undo
          assembly.parts.reload.should be_empty
          Part.find(:all).should be_empty
        end
      end

      describe "Undo deletion" do
        it "should undo the deletion of part and its association when the transaction is rolled back" do
          assembly = Assembly.create!(:name => 'assembly')
          part = Part.create!(:name => 'part', :assemblies => [assembly])

          assembly.parts.should == [part]
          part.assemblies.should == [assembly]

          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          part.destroy

          assembly.parts.reload.should be_empty

          UndoTransaction.find(@undo_transaction.id).undo
          assembly.reload.parts.should == [part]
          part.assemblies.reload.should == [assembly]
          Part.find(part.id).should == part
        end
      end

      describe "Undo updation" do
        it "should undo the updated associations when transaction is rolled back" do
          assembly_1 = Assembly.create!(:name => 'assembly_1')
          assembly_2 = Assembly.create!(:name => 'assembly_2')
          part = Part.create!(:name => 'part', :assemblies => [assembly_1])

          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          part.assemblies = [assembly_2]

          UndoTransaction.find(@undo_transaction.id).undo
          part.assemblies.reload.should == [assembly_1]
        end

        it "should undo the updation of collection associations when transaction is rolled back" do
          assembly_1 = Assembly.create!(:name => 'assembly_1')

          part_1 = Part.create!(:name => 'part_1')
          part_2 = Part.create!(:name => 'part_2')
          part_3 = Part.create!(:name => 'part_3')

          assembly_1.part_ids = [part_1.id, part_2.id]

          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          assembly_1.part_ids = [part_2.id, part_3.id]
          assembly_1.reload.parts.should == [part_2, part_3]
          UndoTransaction.find(@undo_transaction.id).undo
          assembly_1.reload.parts.should == [part_2, part_1]
          Part.find(:all).should have(3).things
        end

        it "should undo the updation of collection associations done using '<<' when transaction is rolled back" do
          assembly_1 = Assembly.create!(:name => 'assembly_1')

          part_1 = Part.create!(:name => 'part_1')
          part_2 = Part.create!(:name => 'part_2')
          part_3 = Part.create!(:name => 'part_3')

          assembly_1.parts = [part_1, part_2]

          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          assembly_1.parts << part_3

          assembly_1.reload.parts.should == [part_1, part_2, part_3]
          UndoTransaction.find(@undo_transaction.id).undo
          assembly_1.reload.parts.should == [part_1, part_2]
          Part.find(:all).should have(3).things
        end
      end

      after :each do
        set_undo_transaction_to_nil
        delete_all_records([UndoTransaction, UndoRecord, Assembly, Part])
        ActiveRecord::Base::connection.execute('delete from assemblies_parts')
      end

      after(:all) do
        connection = ActiveRecord::Base::connection
        begin
          connection.drop_table "assemblies"
          connection.drop_table "parts"
          connection.drop_table "assemblies_parts"
        rescue
          p "Unable to drop tables"
        end
      end
    end
  end
end
