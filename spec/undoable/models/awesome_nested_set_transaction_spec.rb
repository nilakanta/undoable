require File.dirname(__FILE__) + '/../../spec_helper'

class Category < ActiveRecord::Base
  acts_as_nested_set :dependent => :destroy, :scope => [:music_type]
end

module Undoable
  module Models
    module AwesomeNestedSet
      describe "awesome nested set" do
        before :all do
          connection = ActiveRecord::Base.connection
          begin
            connection.create_table :categories, :force => true do |t|
              t.string :name
              t.integer :parent_id
              t.string :music_type
              t.integer :lft
              t.integer :rgt
              t.timestamps
            end
          rescue Exception => e
            p "creation of table failed: #{e}"
          end
        end

        after(:all) do
          connection = ActiveRecord::Base::connection
          begin
            connection.drop_table :categories
          rescue
            p "Unable to drop tables #{e}"
          end
        end

        def create_nested_set
          @science = Category.create!(:name => 'Science')
          @physics = Category.create!(:name => 'Physics')
          @mathematics = Category.create!(:name => 'Mathematics')
          @gravity = Category.create!(:name => 'Gravity')
          @calculus = Category.create!(:name => 'Calculus')
          @physics.move_to_child_of(@science)
          @gravity.move_to_child_of(@physics)
          @mathematics.move_to_child_of(@science)
          @calculus.move_to_child_of(@mathematics)
          @science.reload
        end

        before :each do
          set_undo_transaction_to_nil
          @undo_transaction = UndoTransaction.create!
        end

        after :each do
          set_undo_transaction_to_nil
          delete_all_records([UndoTransaction, UndoRecord, Category])
        end

        describe "Undo Creation" do
          it "should undo the creation of awesome nested set" do
            ActiveRecord::Base.undo_transaction = @undo_transaction.id

            create_nested_set
            Category.count.should == 5

            UndoTransaction.find(@undo_transaction.id).undo
            Category.count.should be_zero
          end
        end

        describe "Undo Deletion" do
          it "should restore the affected nodes when a node is deleted" do
            create_nested_set
            Category.count.should == 5

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            @science.destroy
            Category.count.should == 0

            UndoTransaction.find(@undo_transaction.id).undo
            nested_set_after_undo = Category.find(:all)
            nested_set_after_undo.should equal_sets([@science, @physics, @gravity, @mathematics, @calculus])
          end
        end

        describe "Undo Updation" do
          before(:each) do
            create_nested_set
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
          end

          it "should restore the affected nodes when a node is updated" do
            @physics.right_sibling.should == @mathematics
            @physics.move_to_right_of(@mathematics)
            @physics.right_sibling.should be_nil

            UndoTransaction.find(@undo_transaction.id).undo
            @physics.reload.right_sibling.should == @mathematics.reload
          end

          it "should restore the affected nodes when a node is moved to the root node" do
            @physics.move_to_root
            @mathematics.siblings.should be_empty
            @science.reload.children.should equal_sets([@mathematics])
            @science.reload.descendants.should equal_sets([@mathematics, @calculus])

            UndoTransaction.find(@undo_transaction.id).undo

            @mathematics.reload.siblings.should equal_sets([@physics])
            @science.reload.children.should equal_sets([@physics, @mathematics])
            @science.reload.descendants.should equal_sets([@physics, @mathematics, @calculus, @gravity])
          end

          it "should restore the affected nodes when a node is added" do
            algebra = Category.create!(:name => 'Algebra')
            algebra.move_to_child_of(@mathematics)
            Category.count.should == 6
            @mathematics.children.should equal_sets([@calculus, algebra])

            UndoTransaction.find(@undo_transaction.id).undo

            Category.count.should == 5
            @mathematics.children.should equal_sets([@calculus])
          end

          it "should restore the affected nodes when a non leaf node is deleted" do
            @mathematics.destroy
            Category.count.should == 3
            @science.children.should equal_sets([@physics])
            @science.descendants.should equal_sets([@physics, @gravity])
            @physics.right_sibling.should be_nil

            UndoTransaction.find(@undo_transaction.id).undo

            Category.count.should == 5
            @science.children.should equal_sets([@physics, @mathematics])
            @science.descendants.should equal_sets([@physics, @gravity, @mathematics, @calculus])
            @physics.right_sibling.should == @mathematics
          end
        end

        describe "awesome nested set scope" do
          before(:each) do
            @music = Category.create!(:name => 'Music')
            @english = Category.create!(:name => 'English')
            @hindi = Category.create!(:name => 'Hindi')
            @oriya = Category.create!(:name => 'Oriya')
            @chinese = Category.create!(:name => 'Chinese')

            @english.move_to_child_of(@music)
            @hindi.move_to_child_of(@music)
            @oriya.move_to_child_of(@music)
            @chinese.move_to_child_of(@music)

            @english.update_attributes(:music_type => 'western')
            @hindi.update_attributes(:music_type => 'indian')
            @oriya.update_attributes(:music_type => 'indian')
            @chinese.update_attributes(:music_type => 'eastern')
            
            assert_initial_siblings
          end

          def assert_initial_siblings
            @hindi.siblings.should equal_sets([@oriya])
            @oriya.left_sibling.should == @hindi
            @english.siblings.should be_empty
            @chinese.siblings.should be_empty
          end

          it "should restore the nested set back when transaction is rolled back after a node deletion" do
            ActiveRecord::Base.undo_transaction = @undo_transaction.id

            @hindi.destroy
            @oriya.left_sibling.should be_nil
            @english.siblings.should be_empty
            @chinese.siblings.should be_empty

            UndoTransaction.find(@undo_transaction).undo
            assert_initial_siblings
          end

          it "should restore the nested set back when transaction is rolled back after node updations" do
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            
            spanish = Category.create!(:name => 'Spanish')
            spanish.move_to_child_of(@music)
            spanish.update_attributes(:music_type => 'western')
            @oriya.move_to_left_of(@hindi)
            
            @english.siblings.should equal_sets([spanish])
            @english.right_sibling.should == spanish
            @oriya.left_sibling.should be_nil
            @oriya.right_sibling.should == @hindi
            
            UndoTransaction.find(@undo_transaction).undo
            
            @oriya.reload
            assert_initial_siblings
          end
        end
      end
    end
  end
end
