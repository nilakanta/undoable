require File.dirname(__FILE__) + '/../../spec_helper'

class Supplier < ActiveRecord::Base
  has_one :account
  has_one :account_history, :through => :account
  validates_presence_of :name
end

class Account < ActiveRecord::Base
  belongs_to :supplier
  has_one :account_history
  validates_presence_of :name
end

class AccountHistory < ActiveRecord::Base
  validates_presence_of :name
end

module Undoable
  module Models
    module HasOneThroughRelation
      describe "Has one through" do
        before :all do
          connection = ActiveRecord::Base.connection
          begin
            connection.create_table "suppliers", :force => true do |t|
              t.string :name
              t.timestamps
            end

            connection.create_table "accounts", :force => true do |t|
              t.string :name
              t.integer :supplier_id
              t.integer :account_history_id
              t.timestamps
            end

            connection.create_table "account_histories", :force => true do |t|
              t.integer :account_id
              t.string :name
              t.timestamps
            end
          rescue Exception => e
          end
        end

        before :each do
          @undo_transaction = UndoTransaction.create!
          set_undo_transaction_to_nil
        end

        describe "Undo creation" do
          it "should undo has_one through relationship creation" do
            account_history = AccountHistory.create!(:name=>"account_history")
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            supplier = Supplier.create!(:name => 'supplier', :account => Account.create!(:name => 'account', :account_history => account_history))

            supplier.account.should_not be_nil

            UndoTransaction.find(@undo_transaction.id).undo
            Supplier.find(:all).should be_empty
            Account.find_all_by_supplier_id(supplier.id).should be_empty
            AccountHistory.find(:all).should have(1).thing
          end
        end

        describe "Undo deletion" do
          it "should undo has_many through association deletion" do
            account_history = AccountHistory.create!(:name => "account_historyx")
            account = Account.create!(:name => 'account', :account_history => account_history)
            supplier = Supplier.create!(:name => 'supplier', :account => account)

            supplier.reload.account_history.should_not be_nil

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            supplier.destroy
            Supplier.find(:all).should be_empty
            AccountHistory.find(:all).should have(1).thing
            Account.find(:all).should have(1).thing

            UndoTransaction.find(@undo_transaction.id).undo
            Account.find(:all).should have(1).thing
            recovered_supplier = Supplier.find(supplier.id)

            recovered_supplier.account_history.should == AccountHistory.find_by_name("account_historyx")
            recovered_supplier.account.should_not be_nil
          end
        end

        describe "Undo updation" do
          it "should undo updated associations when transaction is rolled back" do
            account_history = AccountHistory.create!(:name => "account_history")
            account = Account.create!(:name => "account", :account_history => account_history)
            supplier = Supplier.create!(:name => 'supplierx', :account => account)

            other_account_history = AccountHistory.create!(:name => "other_account_history")

            ActiveRecord::Base.undo_transaction = @undo_transaction.id

            supplier.account.account_history = other_account_history
            supplier.account.save!
            supplier.account_history.should == other_account_history

            UndoTransaction.find(@undo_transaction.id).undo
            supplier.reload.account_history.should == account_history
            Account.find(:all).should have(1).thing
          end
        end

        after :each do
          set_undo_transaction_to_nil
          delete_all_records([UndoTransaction, UndoRecord, Supplier, Account, AccountHistory])
        end

        after :all do
          connection = ActiveRecord::Base::connection
          begin
            connection.drop_table "suppliers"
            connection.drop_table "accounts"
            connection.drop_table "account_histories"
          rescue
            p "Unable to drop tables"
          end
        end
      end
    end
  end
end
