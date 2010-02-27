require File.dirname(__FILE__) + '/../../spec_helper'

class Customer < ActiveRecord::Base
  has_many :orders, :dependent => :destroy
  validates_presence_of :name
end

class Order < ActiveRecord::Base
  belongs_to :customer
  validates_presence_of :name
end

class CustomerWithOrderNullify < ActiveRecord::Base
  has_many :nullified_orders, :dependent => :nullify
end

class NullifiedOrder < ActiveRecord::Base
  belongs_to :customer_with_order_nullify
end

module Undoable
  module Models
    module HasManyRelation   
      describe "Has many" do
        before :all do
          connection = ActiveRecord::Base.connection
          begin
            connection.create_table "customers", :force => true do |t|
              t.string :name
              t.timestamps
            end

            connection.create_table "orders", :force => true do |t|
              t.string :name
              t.integer :customer_id
              t.timestamps
            end

            connection.create_table "customer_with_order_nullifies", :force => true do |t|
              t.string :name
              t.timestamps
            end

            connection.create_table "nullified_orders", :force => true do |t|
              t.string :name
              t.integer :"customer_with_order_nullify_id"
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
          it "should remove the association when transaction is rolled back" do
            order = Order.create!(:name => 'order')
            ActiveRecord::Base.undo_transaction = @undo_transaction.id

            customer = Customer.create!(:name => 'customer', :orders => [order])
            UndoTransaction.find(@undo_transaction.id).undo
            Order.find_all_by_customer_id(customer.id).should be_empty
            Customer.find(:all).should == []
          end

          it "should delete the child when the customer creation is rolled back" do
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            customer = Customer.create!(:name => 'customer')
            order = Order.create!(:name => 'order', :customer => customer)
            UndoTransaction.find(@undo_transaction.id).undo
            Customer.find(:all).should be_empty
            Order.find(:all).should be_empty
          end
        end

        describe "Undo deletion" do
          before(:each) do
            @customer = Customer.create!(:name => 'customer')
            @child = Order.create!(:name => 'order', :customer => @customer)
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
          end
          
          it "should undo deletion of child and its association when customer is undeleted" do
            @customer.destroy

            Customer.find(:all).should be_empty
            Order.find(:all).should be_empty

            UndoTransaction.find(@undo_transaction.id).undo
            recovered_customer = Customer.find(@customer.id)
            recovered_child = Order.find(@child.id)
            recovered_customer.orders.should == [recovered_child]
            recovered_child.customer.should == recovered_customer
          end

          it "should recreate relationships when child is undeleted" do
            @child.destroy

            UndoTransaction.find(@undo_transaction.id).undo
            recovered_child = Order.find(@child.id)
            @customer.orders.should == [recovered_child]
            recovered_child.customer.should == @customer
          end
        end

        describe "Undo updation" do
          it "should undo the updated associations when the transaction is rolled back" do
            customer_1 = Customer.create!(:name => 'customer_1')
            customer_2 = Customer.create!(:name => 'customer_2')
            child_1 = Order.create!(:name => 'order_1', :customer => customer_1)
            child_2 = Order.create!(:name => 'child_2', :customer => customer_1)

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            child_1.update_attributes(:customer => customer_2)

            customer_1.reload.orders.should == [child_2]
            customer_2.reload.orders.should == [child_1]
      
            UndoTransaction.find(@undo_transaction.id).undo
            customer_2.reload.orders.should be_empty
            customer_1.reload.orders.should == [child_1, child_2]            
          end

          it "should undo the updation of association collection for dependent destroy case" do
            child_1 = Order.create!(:name => 'order_1')
            child_2 = Order.create!(:name => 'child_2')
            child_3 = Order.create!(:name => 'child_3')
            customer = Customer.create!(:name => "test_customer", :orders => [child_1, child_2])

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            customer.orders = [child_2, child_3]

            Order.find_by_id(child_1.id).should be_nil
            UndoTransaction.find(@undo_transaction.id).undo
            customer.orders.reload.should == [child_1, child_2]
          end

          it "should undo the updation of association collection for no dependent destroy" do
            child_1 = NullifiedOrder.create!(:name => 'order_1')
            child_2 = NullifiedOrder.create!(:name => 'child_2')
            child_3 = NullifiedOrder.create!(:name => 'child_3')
            customer = CustomerWithOrderNullify.create!(:name => "test_customer", :nullified_orders => [child_1, child_2])

            NullifiedOrder.find(:all).size.should == 3

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            customer.nullified_orders = [child_2, child_3]

            UndoTransaction.find(@undo_transaction.id).undo
            child_1.reload.customer_with_order_nullify.should == customer
            customer.nullified_orders.reload.should == [child_1, child_2]
            NullifiedOrder.find(:all).size.should == 3
          end

          it "should undo the updation of association collection done using '<<' for dependent destroy case" do
            child_1 = Order.create!(:name => 'order_1')
            child_2 = Order.create!(:name => 'child_2')
            child_3 = Order.create!(:name => 'child_3')
            child_4 = Order.create!(:name => 'child_4')
            customer = Customer.create!(:name => "test_customer", :orders => [child_1, child_2])

            Order.find(:all).size.should == 4
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            customer.orders << [child_3, child_4]

            UndoTransaction.find(@undo_transaction.id).undo
            customer.orders.reload.should == [child_1, child_2]
          end

          it "should undo the updation of association collection done using '<<' for dependent nullify" do
            child_1 = NullifiedOrder.create!(:name => 'order_1')
            child_2 = NullifiedOrder.create!(:name => 'child_2')
            child_3 = NullifiedOrder.create!(:name => 'child_3')
            customer = CustomerWithOrderNullify.create!(:name => "test_customer", :nullified_orders => [child_1, child_2])

            NullifiedOrder.find(:all).size.should == 3

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            customer.nullified_orders << [child_2, child_3]

            UndoTransaction.find(@undo_transaction.id).undo
            child_1.reload.customer_with_order_nullify.should == customer
            customer.nullified_orders.reload.should == [child_1, child_2]
            NullifiedOrder.find(:all).size.should == 3
          end
        end

        after :each do
          delete_all_records([UndoTransaction,UndoRecord,Customer,Order,CustomerWithOrderNullify,NullifiedOrder])
          set_undo_transaction_to_nil
        end

        after :all do
          connection = ActiveRecord::Base::connection
          begin
            connection.drop_table "customers"
            connection.drop_table "orders"
            connection.drop_table "customer_with_order_nullifies"
            connection.drop_table "nullified_orders"
          rescue
            p "Unable to drop tables"
          end
        end
      end
    end
  end
end
