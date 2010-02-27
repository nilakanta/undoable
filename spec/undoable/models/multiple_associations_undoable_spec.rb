require File.dirname(__FILE__) + '/../../spec_helper'

class TestParent < ActiveRecord::Base
  has_many :test_children, :dependent => :destroy
  has_one :beta, :dependent => :destroy
  has_and_belongs_to_many :alphas
  validates_presence_of :name
end

class TestChild < ActiveRecord::Base
  belongs_to :test_parent
  validates_presence_of :name
end

class Alpha < ActiveRecord::Base
  has_and_belongs_to_many :test_parents
  validates_presence_of :name
end

class Beta < ActiveRecord::Base
  belongs_to :test_parent
  validates_presence_of :name
end

module Undoable
  module Models
    module MultipleAssociations
      describe "multiple associations" do
        before :all do
          connection = ActiveRecord::Base.connection
          setup_db_tables(connection)
          begin
            connection.create_table "test_parents", :force => true do |t|
              t.string :name
              t.timestamps
            end

            connection.create_table "test_children", :force => true do |t|
              t.string :name
              t.integer :test_parent_id
              t.timestamps
            end

            connection.create_table "alphas", :force => true do |t|
              t.string :name
              t.timestamps
            end

            connection.create_table "betas", :force => true do |t|
              t.string :name
              t.integer :test_parent_id
              t.timestamps
            end

            connection.create_table "alphas_test_parents", :force => true, :id => false do |t|
              t.integer :alpha_id
              t.integer :test_parent_id
              t.timestamps
            end
          rescue
            p "Error Unable to create test tables"
          end
        end

        before :each do
          @undo_transaction = UndoTransaction.create!
        end

        describe "Undo creation" do
          it "should remove the all the associations when transaction is rolled back" do
            parent = TestParent.create!(:name => 'parent')

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            alpha = Alpha.create!(:name => 'alpha', :test_parents => [parent])
            beta = Beta.create!(:name => 'beta', :test_parent => parent)
            child = TestChild.create!(:name => 'child', :test_parent => parent)

            UndoTransaction.find(@undo_transaction.id).undo

            parent.reload.test_children.should be_empty
            parent.reload.beta.should be_nil
            parent.reload.alphas.should be_empty

            TestParent.find(:all).should == [parent]
          end
        end

        describe "Undo deletion" do
          it "should undo deletion of child and its association when parent is undeleted" do
            parent = TestParent.create!(:name => 'parent')
            beta = Beta.create!(:name => 'beta', :test_parent => parent)
            alpha = Alpha.create!(:name => 'alpha', :test_parents => [parent])
            child = TestChild.create!(:name => 'child', :test_parent => parent)

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            parent.destroy

            TestParent.find(:all).should be_empty
            TestChild.find(:all).should be_empty
            Beta.find(:all).should be_empty
            alpha.reload.test_parents.should be_empty

            UndoTransaction.find(@undo_transaction.id).undo

            recovered_parent = TestParent.find(parent.id)
            recovered_child = TestChild.find_by_test_parent_id(parent.id)
            recovered_beta = Beta.find_by_test_parent_id(parent.id)

            recovered_parent.test_children.should == [recovered_child]
            recovered_parent.beta.should == recovered_beta
            alpha.reload.test_parents.should == [recovered_parent]
          end
        end

        describe "Undo Updation" do
          it "should undo the upadation of association collection when transaction is rolled back" do
            parent = TestParent.create!(:name => 'parent')
            beta_1 = Beta.create!(:name => 'beta_1', :test_parent => parent)
            beta_2 = Beta.create!(:name => 'beta_2')
            alpha_1 = Alpha.create!(:name => 'alpha_1', :test_parents => [parent])
            alpha_2 = Alpha.create!(:name => 'alpha_2')
            child_1 = TestChild.create!(:name => 'child_1', :test_parent => parent)
            child_2 = TestChild.create!(:name => 'child_2')

            ActiveRecord::Base.undo_transaction = @undo_transaction.id

            parent.beta = beta_2
            parent.alphas << [alpha_2]
            parent.test_children = [child_2]

            UndoTransaction.find(@undo_transaction.id).undo

            parent.reload.beta.should == beta_1
            parent.reload.alphas.should == [alpha_1]
            parent.reload.test_children.should == [child_1]
          end
        end

        after :each do
          set_undo_transaction_to_nil
          delete_all_records([UndoTransaction, UndoRecord, TestChild, TestParent, Alpha, Beta])
        end

        after :all do
          connection = ActiveRecord::Base::connection
          begin
            connection.drop_table "test_parents"
            connection.drop_table "test_children"
            connection.drop_table "alphas"
            connection.drop_table "betas"
            connection.drop_table "alphas_test_parents"
          rescue
            p "Unable to drop tables"
          end
        end
      end
    end
  end
end
