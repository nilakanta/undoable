require File.dirname(__FILE__) + '/../../spec_helper'

module Undoable
  module Models
    describe UndoRecord do

      class TestUndoableRecord
        attr_accessor :attributes

        def initialize(attributes = {})
          @attributes = attributes
        end

        def self.reflections
          @reflections || {}
        end

        def self.reflections=(vals)
          @reflections = vals
        end

        def id
          attributes['id']
        end

        def id=(val)
          attributes['id'] = val
        end

        def name=(val)
          attributes['name'] = val
        end

        def value=(val)
          attributes['value'] = val
        end

        def self.undoable_associations
          nil
        end
        
        def write_attribute(key, value)
          send("#{key}=", value)
        end
      end

      class TestUndoableAssociationRecord < TestUndoableRecord
        def self.reflections
          @reflections || {}
        end

        def self.reflections=(vals)
          @reflections = vals
        end
      end

      class TestUndoableSubAssociationRecord < TestUndoableRecord
        def self.reflections
          @reflections || {}
        end

        def self.reflections=(vals)
          @reflections = vals
        end
      end

      before(:each) do
        TestUndoableRecord.reflections = nil
        TestUndoableAssociationRecord.reflections = nil
        TestUndoableSubAssociationRecord.reflections = nil
      end

      describe "using database" do
        it "should set the revision number before it creates the record" do
          UndoRecord.delete_all
          revision1 = UndoRecord.new("Create", TestUndoableRecord.new)
          revision2 = UndoRecord.new("Create", TestUndoableRecord.new)
          undo_transaction = UndoTransaction.create!(:undo_records => [revision1, revision2])
          revision1.revision.should == 1
          revision2.revision.should == 2
          revision2.revision = 20
          revision2.save!
          revision3 = UndoRecord.new("Create", TestUndoableRecord.new)
          undo_transaction.undo_records << revision3
          revision3.save!
          revision3.revision.should == 21
          UndoRecord.delete_all
        end

        it "should serialize all the attributes of the original model" do
          attributes = {'id' => 1, 'name' => 'revision', 'value' => 5}
          revision = UndoRecord.new("Create", TestUndoableRecord.new(attributes))
          revision.undoable_id.should == 1
          revision.undoable_type.should == "Undoable::Models::TestUndoableRecord"
          revision.revision_attributes.should == attributes
        end

        it "should be able to restore the original model" do
          attributes = {'id' => 1, 'name' => 'revision', 'value' => 5}
          revision = UndoRecord.new("Create", TestUndoableRecord.new(attributes))
          revision.data = Marshal.dump(attributes)
          restored = Restore::restore(revision)
          restored.class.should == TestUndoableRecord
          restored.id.should == 1
          restored.attributes.should == attributes
        end

        it "should really save the revision records to the database and restore without any mocking" do
          UndoRecord.delete_all
          UndoRecord.count.should == 0

          UndoRecord.delete_all
          undo_transaction = UndoTransaction.create!

          attributes = {'id' => 1, 'value' => rand(1000000)}
          original = TestUndoableRecord.new(attributes)
          original.attributes['name'] = 'revision 1'
          revision1 = UndoRecord.new("Create", original)
          undo_transaction.undo_records << revision1
          undo_transaction.save!
          first_revision = UndoRecord.find(:first)
          original.attributes['name'] = 'revision 2'
          revision2 = UndoRecord.new("Create", original)
          undo_transaction.undo_records << revision2
          undo_transaction.save!
          original.attributes['name'] = 'revision 3'
          revision3 = UndoRecord.new("Create", original)
          undo_transaction.undo_records << revision3
          undo_transaction.save!
          UndoRecord.count.should == 3

          record = Restore::restore(UndoRecord.find_revision(TestUndoableRecord, 1, 1))
          record.class.should == TestUndoableRecord
          record.id.should == 1
          record.attributes.should == attributes.merge('name' => 'revision 1')

          UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 2)
          UndoRecord.count.should == 2
          UndoRecord.find_by_id(first_revision.id).should == nil
          UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 0, :minimum_age => 1.week)
          UndoRecord.count.should == 2
          UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 0)
          UndoRecord.count.should == 0
        end

        after :each do
          UndoRecord.delete_all
          UndoTransaction.delete_all
        end
      end

      describe "using expectations" do
        it "should be able to truncate the revisions for a record" do
          revision = UndoRecord.new("Create", TestUndoableRecord.new(:name => 'name'))
          revision.revision = 20
          UndoRecord.should_receive(:find).with(:first, :conditions => ['undoable_type = ? AND undoable_id = ?', 'Undoable::Models::TestUndoableRecord', 1], :offset => 15, :order => 'revision DESC').and_return(revision)
          UndoRecord.should_receive(:delete_all).with(['undoable_type = ? AND undoable_id = ? AND revision <= ?', 'Undoable::Models::TestUndoableRecord', 1, 20])
          UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 15)
        end

        it "should not truncate the revisions for a record if it doesn't have enough" do
          UndoRecord.should_receive(:find).with(:first, :conditions => ['undoable_type = ? AND undoable_id = ?', 'Undoable::Models::TestUndoableRecord', 1], :offset => 15, :order => 'revision DESC').and_return(nil)
          UndoRecord.should_receive(:delete_all).never
          UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 15)
        end

        it "should not truncate the revisions for a record if no limit or minimum_age is set" do
          UndoRecord.should_receive(:find).never
          UndoRecord.should_receive(:delete_all).never
          UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => nil, :minimum_age => nil)
        end

        it "should be able to find a record by revisioned type and id" do
          revision = UndoRecord.new("Create", TestUndoableRecord.new(:name => 'name'))
          UndoRecord.should_receive(:find).with(:first, :conditions => {:undoable_type => 'Undoable::Models::TestUndoableRecord', :undoable_id => 1, :revision => 2}).and_return(revision)
          UndoRecord.find_revision(TestUndoableRecord, 1, 2).should == revision
        end
      end

    end
  end
end