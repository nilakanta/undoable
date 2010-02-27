require File.dirname(__FILE__) + '/../../../spec_helper'

module Undoable::Rails::ActiveRecord::Base
  module ClassMethods
    def undoable_exclusions
      load_undoable_exclusions
    end

    private
    def undoable_exclusions_file
      File.dirname(__FILE__) + '/undoable_exclusions.yml'
    end
  end
end

describe "Active Record: Base" do
  class Booga < ActiveRecord::Base
  end

  class Wooga < ActiveRecord::Base
  end

  it "undoable models should be excluded from including Undoable" do
    Undoable::Models::UndoRecord.private_methods.should_not include("create_undo_records")
    Undoable::Models::UndoTransaction.private_methods.should_not include("create_undo_records")
  end

  it "should exclude models that are in the exclusion file from including Undoable" do
    Booga.private_methods.should_not include("create_undo_records")
  end

  it "all other models should include Undoable" do
    Wooga.private_methods.should include("create_undo_records")
  end
end
