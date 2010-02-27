require File.dirname(__FILE__) + '/../../spec_helper'

class Picture < ActiveRecord::Base
  belongs_to :imageable, :polymorphic => true
end

class Employee < ActiveRecord::Base
  has_many :pictures, :as => :imageable
end

class Product < ActiveRecord::Base
  has_many :pictures, :as => :imageable
end

module Undoable
  module Models
    module HasManyPolymorphicRelation
      describe "Has many polymorphic" do
        before :all do
          connection = setup_db_connection
          setup_db_tables connection
          begin
            connection.create_table :pictures, :force => true do |t|
              t.string :name
              t.references :imageable, :polymorphic => true
              t.timestamps
            end

            connection.create_table :employees, :force => true do |t|
              t.string :name
              t.timestamps
            end

            connection.create_table :products, :force => true do |t|
              t.string :name
              t.timestamps
            end

          rescue Exception => e
            p "creation of table failed: #{e}"
          end
        end

        before :each do
          @undo_transaction = UndoTransaction.create!
          set_undo_transaction_to_nil

          @judith = Picture.create!(:name => 'Judith')
          @mona_lisa = Picture.create!(:name => 'Mona Lisa')
          @laura = Picture.create!(:name => 'Laura')
        end

        describe "Undo creation" do
          it "should undo has_many polymorphic relationship creation" do
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            wooga = Employee.create!(:name => 'wooga')
            wooga.pictures = [@judith]
            booga = Product.create!(:name => 'booga', :pictures => [@mona_lisa])

            UndoTransaction.find(@undo_transaction.id).undo

            Employee.find(:all).should be_empty
            Product.find(:all).should be_empty
            pictures = Picture.find(:all)
            pictures.should have(3).thing
            pictures.should == [@judith, @mona_lisa, @laura]
          end
        end

        describe "Undo deletion" do
          it "should undo has_many polymorphic association deletion" do
            wooga = Employee.create!(:name => 'wooga', :pictures => [@judith, @laura])
            booga = Product.create!(:name => 'booga', :pictures => [@mona_lisa])

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            wooga.destroy
            booga.destroy
            Product.find(:all).should be_empty
            Employee.find(:all).should be_empty
            Picture.find(:all).should have(3).thing

            UndoTransaction.find(@undo_transaction.id).undo

            recovered_product = Product.find(booga.id)
            recovered_employee = Employee.find(wooga.id)

            recovered_employee.pictures.should == [@judith, @laura]
            recovered_product.pictures.should == [@mona_lisa]
          end
        end

        describe "Undo updation" do
          it "should undo updated polymorphic associations when transaction is rolled back" do
            bacchus = Picture.new(:name => 'Bacchus')

            wooga = Employee.create!(:name => 'wooga', :pictures => [@judith])
            booga = Product.create!(:name => 'booga', :pictures => [@mona_lisa])

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            wooga.pictures << bacchus
            booga.pictures << @laura

            wooga.reload.pictures.should == [@judith, bacchus]
            booga.reload.pictures.should == [@mona_lisa, @laura]
            UndoTransaction.find(@undo_transaction.id).undo

            wooga.reload.pictures.should == [@judith]
            booga.reload.pictures.should == [@mona_lisa]
          end

          it "should undo updated polymorphic association" do
            wooga = Employee.create!(:name => 'wooga', :pictures => [@judith, @laura, @mona_lisa])

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            wooga.update_attributes(:name => 'wooga - 1')
            UndoTransaction.find(@undo_transaction.id).undo

            wooga.reload.name.should == "wooga"
          end
        end

        after :each do
          set_undo_transaction_to_nil
          delete_all_records([UndoTransaction, UndoRecord, Product, Employee, Picture])
        end

        after :all do
          connection = ActiveRecord::Base::connection
          begin
            connection.drop_table :employees
            connection.drop_table :products
            connection.drop_table :pictures
          rescue
            p "Unable to drop tables #{e}"
          end
        end
      end
    end
  end
end
