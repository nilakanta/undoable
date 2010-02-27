require File.dirname(__FILE__) + '/../../spec_helper'

class TestKlass < ActiveRecord::Base
  validates_presence_of :name
  before_destroy :name_not_undeletable?

  def name_not_undeletable?
    name != 'undeletable'
  end
end

module Undoable
  module Models
    describe Reverse do
      describe "Simple undo" do
        before :all do
          connection = ActiveRecord::Base.connection
          begin
            connection.create_table "test_klasses", :force => true do |t|
              t.string :name
              t.timestamps
            end

          rescue
            p "Error Unable to create test tables"
          end
        end

        before :each do
          @undo_transaction = UndoTransaction.create!
        end

        describe "Creation" do
          before(:each) do
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
          end

          it "should create a new undo_transaction" do
            TestKlass.create!(:name => 'name')
            UndoTransaction.find(:all).size.should == 1
            UndoRecord.find_all_by_operation("Create").size.should == 1
          end

          it "should not create a new undo_transaction if object has errors on creation" do
            TestKlass.create(:name => nil)
            UndoTransaction.find(:all).size.should == 1
            UndoRecord.find_all_by_operation("Create").should be_empty
          end

          it "should be able to undo a creation" do
            test_klass = TestKlass.create!(:name => 'name')
            UndoRecord.find_all_by_operation("Create").first.undo.should == test_klass
            TestKlass.find(:first).should be_nil
          end
        end

        describe "Deleting" do
          it "should create a new undo_transaction" do
            test_klass = TestKlass.create!(:name => 'name')

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            test_klass.destroy
            UndoTransaction.find(:all).size.should == 1
            UndoRecord.find_all_by_operation("Destroy").size.should == 1
          end

          it "should not create a new undo_transaction if object has errors on destroy" do
            test_klass = TestKlass.create!(:name => 'undeletable')

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            test_klass.destroy
            UndoTransaction.find(:all).size.should == 1
            UndoRecord.find_all_by_operation("Destroy").should be_empty
          end

          it "should be able to undo a destroy" do
            test_klass = TestKlass.create!(:name => 'name')

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            test_klass.destroy
            UndoRecord.find_all_by_operation("Destroy").first.undo.should be_true
            restored_test_klass = TestKlass.find(:first)
            restored_test_klass.should == test_klass
          end
        end

        describe "Updation" do
          before(:each) do
            @test_klass = TestKlass.create!(:name => 'name')
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
          end
          it "should create a new undo_transaction" do
            @test_klass.update_attributes(:name => 'new_name')
            UndoTransaction.find(:all).size.should == 1
            UndoRecord.find_all_by_operation("Update").size.should == 1
          end

          it "should not create a new undo_transaction if object has errors on updation" do
            @test_klass.update_attributes(:name => nil)
            UndoTransaction.find(:all).size.should == 1
            UndoRecord.find_all_by_operation("Update").should be_empty
          end

          it "should be able to undo a update" do
            @test_klass.update_attributes(:name => 'new_name')
            UndoRecord.find_all_by_operation("Update").first.undo.should be_true
            restored_test_klass = TestKlass.find(:first)
            restored_test_klass.should == @test_klass
          end
          
          it "should be able to undo updation done using update_all" do
            TestKlass.create!(:name => 'name2')
            TestKlass.update_all(["name = ?", 'test'], ["name = ?", 'name2'])
            TestKlass.find_by_name('test').should_not be_blank
            UndoTransaction.find(@undo_transaction).undo
            TestKlass.find_by_name('test').should be_nil
          end
        end

        after :each do
          set_undo_transaction_to_nil
          delete_all_records([UndoTransaction, UndoRecord, TestKlass])
        end

        after :all do
          connection = ActiveRecord::Base.connection
          begin
            connection.drop_table "test_klasses", :force => true
          rescue
            p "Error Unable to create test tables"
          end
        end
      end
    end

    describe "Undoable for multiple records" do
      class Foo < ActiveRecord::Base
        validates_presence_of :name
      end

      class Bar < ActiveRecord::Base
        validates_presence_of :name
      end

      before :all do
        connection = ActiveRecord::Base.connection
        begin
          connection.create_table "foos", :force => true do |t|
            t.string :name
            t.timestamps
          end

          connection.create_table "bars", :force => true do |t|
            t.string :name
            t.timestamps
          end
        rescue
          p "Error Unable to create test tables"
        end
      end

      it "should undo all the modification done to multiple records which are under the same transaction" do
        set_undo_transaction_to_nil
        foo_1 = Foo.create!(:name => "foo_1")
        bar_1 = Bar.create!(:name => "bar_1")

        transaction = UndoTransaction.create!
        ActiveRecord::Base.undo_transaction = transaction.id

        Foo.create!(:name => "foo")
        Bar.create!(:name => "bar")
        bar_1.destroy
        foo_1.update_attributes!(:name => "1_oof")
        Foo.find(:all).should have(2).thing
        foo_1.reload.name.should == "1_oof"
        Bar.find(:all).should have(1).thing

        UndoTransaction.find(transaction.id).undo

        Foo.find(:all).should == [foo_1]
        foo_1.reload.name.should == "foo_1"
        Bar.find(:all).should == [bar_1]
      end

      after :each do
        set_undo_transaction_to_nil
        delete_all_records([UndoTransaction, UndoRecord, Foo, Bar])
      end

      after :all do
        connection = ActiveRecord::Base.connection
        begin
          connection.drop_table "foos", :force => true
          connection.drop_table "bars", :force => true
        rescue
          p "Error Unable to create test tables"
        end
      end
    end
  end
end
