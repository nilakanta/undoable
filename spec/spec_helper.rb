ENV["RAILS_ENV"] ||= 'test'
require File.expand_path(File.join(File.dirname(__FILE__), '../../../../', 'config', 'environment'))
require 'spec/autorun'
require 'spec/rails'

Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false

  config.include EqualSetsMatcher  
end

def setup_db_connection
  connection_params = YAML.load_file(RAILS_ROOT + '/config/database.yml')['test']
  ActiveRecord::Base.logger = Logger.new(RAILS_ROOT + "/log/#{RAILS_ENV}.log")
  ActiveRecord::Base.establish_connection(connection_params)
  ActiveRecord::Base.connection
end

def setup_db_tables(connection)
  connection.create_table :undo_records, :force => true do |t|
    t.string  :operation
    t.string  :undoable_type, :limit => 100
    t.integer :undoable_id
    t.integer :revision
    t.binary  :data, :limit => 5.megabytes
    t.integer :undo_transaction_id, :null => false
    t.timestamps
  end
  connection.add_index :undo_records, [:undoable_type, :undoable_id, :revision], :name => :undoable, :unique => true
  connection.create_table :undo_transactions, :force => true do |t|
    t.string :description, :limit => 100
  end
end

def set_undo_transaction_to_nil
  ActiveRecord::Base.undo_transaction = nil
end

def delete_all_records(models)
  models.each{|model| model.delete_all}
end

setup_db_tables(setup_db_connection)