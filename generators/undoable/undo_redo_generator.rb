class UndoableGenerator < Rails::Generator::Base
  def manifest
    record {|m| m.migration_template 'migration.rb', 'db/migrate', :assigns => {}, :migration_file_name => "add_undoable_tables" }
  end
end
