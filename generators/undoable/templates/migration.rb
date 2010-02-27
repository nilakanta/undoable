class AddUndoableTables < ActiveRecord::Migration
  
  def self.up
    create_table :undo_records do |t|
      t.string  :operation
      t.string  :undoable_type, :limit => 100
      t.integer :undoable_id
      t.integer :revision
      t.binary  :data, :limit => 5.megabytes
      t.integer :undo_transaction_id, :null => false
      t.timestamps
    end
    
    add_index :undo_records, [:undoable_type, :undoable_id, :revision], :name => :undoable, :unique => true

    create_table :undo_transactions do |t|
      t.string :description, :limit => 100  
      t.timestamps
    end
  end
  
  def self.down
    drop_table :undo_transactions
    drop_table :undo_records
  end
end