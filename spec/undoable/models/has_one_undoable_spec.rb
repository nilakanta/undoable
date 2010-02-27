require File.dirname(__FILE__) + '/../../spec_helper'

class User < ActiveRecord::Base
  has_one :subscription, :dependent => :destroy
  validates_presence_of :name
end

class Subscription < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :name
end

module Undoable
  module Models
    describe "Has one" do

      before :all do
        connection = ActiveRecord::Base.connection
        begin

          connection.create_table "users", :force => true do |t|
            t.string :name
            t.timestamps
          end

          connection.create_table "subscriptions", :force => true do |t|
            t.string :name
            t.integer :user_id
            t.timestamps
          end
        rescue
          p "Error Unable to create test tables"
        end
      end

      before :each do
        set_undo_transaction_to_nil
        @undo_transaction = UndoTransaction.create!
      end

      describe "Undo creation" do
        it "should remove the association when transaction is rolledback" do
          user = User.create!(:name => 'user')
          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          subscription = Subscription.create!(:name => 'subscription', :user_id => user.id)
          UndoTransaction.find(@undo_transaction.id).undo
          Subscription.find_all_by_user_id(user.id).should be_empty
          User.find(:all).should == [user]
        end

        it "should delete the subscription when the user creation is rolled back" do
          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          user = User.create!(:name => 'user')
          subscription = Subscription.create!(:name => 'subscription', :user_id => user.id)
          UndoTransaction.find(@undo_transaction.id).undo
          User.find(:all).should be_empty
          Subscription.find(:all).should be_empty
        end
      end

      describe "Undo deletion" do
        it "should undo deletion of subscription and its association when user is undeleted" do
          user = User.create!(:name => 'user')
          subscription = Subscription.create!(:name => 'subscription', :user_id => user.id)

          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          user.destroy

          User.find(:all).should be_empty
          Subscription.find(:all).should be_empty
          UndoTransaction.find(@undo_transaction.id).undo
          recovered_user = User.find(user.id)
          recovered_subscription = Subscription.find_by_user_id(user.id)
          recovered_user.subscription.should == recovered_subscription
          recovered_subscription.user.should == recovered_user
        end

        it "should recreate relationships when subscription is undeleted" do
          user = User.create!(:name => 'user')
          subscription = Subscription.create!(:name => 'subscription', :user_id => user.id)

          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          subscription.destroy

          UndoTransaction.find(@undo_transaction.id).undo
          recovered_subscription = Subscription.find(subscription.id)
          user.subscription.should == recovered_subscription
          recovered_subscription.user.should == user
        end
      end

      describe "Undo updation" do
        it "should undo the updated associations when the transaction is rolledback" do
          user_1 = User.create!(:name => 'user_1')
          user_2 = User.create!(:name => 'user_2')
          subscription = Subscription.create!(:name => 'subscription', :user_id => user_1.id)

          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          subscription.update_attributes(:user_id => user_2.id)

          user_2.subscription.should == subscription
          user_1.subscription.should be_nil
          UndoTransaction.find(@undo_transaction.id).undo
          user_2.reload.subscription.should be_nil
          user_1.reload.subscription.should == subscription
        end

        it "should undo the association collection updation when transaction is rolled back" do
          user_1 = User.create!(:name => 'user_1')
          subscription_1 = Subscription.create!(:name => 'subscription_1', :user => user_1)
          subscription_2 = Subscription.create!(:name => 'subscription_2')

          ActiveRecord::Base.undo_transaction = @undo_transaction.id
          user_1.subscription = subscription_2

          user_1.reload.subscription.should == subscription_2
          UndoTransaction.find(@undo_transaction.id).undo
          user_1.reload.subscription.should == subscription_1
          Subscription.find(:all).should have(2).things
        end
      end

      after :each do
        set_undo_transaction_to_nil
        delete_all_records([UndoTransaction, UndoRecord, Subscription, User])
      end

      after :all do
        connection = ActiveRecord::Base::connection
        begin
          connection.drop_table "users"
          connection.drop_table "subscriptions"
        rescue
          p "Unable to drop tables"
        end
      end
    end
  end
end
