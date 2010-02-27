require File.dirname(__FILE__) + '/../../spec_helper'

class Physician < ActiveRecord::Base
  has_many :appointments
  has_many :patients, :through => :appointments
  validates_presence_of :name
end

class Appointment < ActiveRecord::Base
  belongs_to :physician
  belongs_to :patient
end

class Patient < ActiveRecord::Base
  has_many :appointments
  has_many :physicians, :through => :appointments
  validates_presence_of :name
end

module Undoable
  module Models
    module HasManyThroughRelation
      describe "Has many through" do
        before :all do
          connection = ActiveRecord::Base.connection
          begin
            connection.create_table "physicians", :force => true do |t|
              t.string :name
              t.timestamps
            end

            connection.create_table "appointments", :force => true do |t|
              t.string :name
              t.integer :patient_id
              t.integer :physician_id
              t.timestamps
            end

            connection.create_table "patients", :force => true do |t|
              t.string :name
              t.timestamps
            end
          rescue Exception => e
            p "Unable to create tables"
          end
        end

        before :each do
          @undo_transaction = UndoTransaction.create!
          set_undo_transaction_to_nil
        end

        describe "Undo creation" do
          it "should undo has_many through relationship creation" do
            patient = Patient.create!(:name => 'patient')
            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            physician = Physician.create!(:name => 'physician', :patients => [patient])

            physician.appointments.should have(1).thing
            physician.patients.should have(1).thing

            UndoTransaction.find(@undo_transaction.id).undo

            Physician.find(:all).should be_empty
            Appointment.find_all_by_physician_id(physician.id).should be_empty
            Patient.find(:all).should have(1).thing
          end
        end

        describe "Undo deletion" do
          it "should undo has_many through association deletion" do
            patient = Patient.create!(:name => "patientx")
            physician = Physician.create!(:name => 'physicianx', :patients => [patient])

            physician.appointments.should have(1).thing
            patient.appointments.should have(1).thing
            physician.patients.should == [patient]
            patient.physicians.should == [physician]

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            physician.destroy
            Physician.find(:all).should be_empty
            Patient.find(:all).should_not be_empty
            
            UndoTransaction.find(@undo_transaction.id).undo
            Appointment.find(:all).should have(1).thing
            recovered_patient = Patient.find(patient.id)
            recovered_physician = Physician.find(physician.id)

            recovered_physician.patients.should == [recovered_patient]
            recovered_patient.physicians.should == [recovered_physician]
          end
        end

        describe "Undo updation" do
          it "should undo updated associations when transaction is rolled back" do
            patient_1 = Patient.create!(:name => "patient_1")
            patient_2 = Patient.create!(:name => "patient_2")
            other_patient = Patient.create!(:name => "other_patient")
            physician = Physician.create!(:name => 'physicianx', :patients => [patient_1, other_patient])

            physician.appointments.should have(2).thing
            physician.patients.should == [patient_1, other_patient]

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            physician.patients = [patient_2, other_patient]
            physician.reload.patients.should == [other_patient, patient_2]


            UndoTransaction.find(@undo_transaction.id).undo
            physician.reload.patients.should == [patient_1, other_patient]
            Appointment.find(:all).should have(2).thing
          end

          it "should undo updated through association" do
            patient = Patient.create!(:name => "patient")
            physician = Physician.create!(:name => 'physician', :patients => [patient])

            physician.appointments.first.name.should be_nil

            ActiveRecord::Base.undo_transaction = @undo_transaction.id
            physician.appointments.first.name = "beta"

            UndoTransaction.find(@undo_transaction.id).undo
            physician.reload.appointments.first.name.should be_nil
          end
        end

        after :each do
          set_undo_transaction_to_nil
          delete_all_records([UndoTransaction, UndoRecord, Physician, Appointment, Patient])
        end

        after :all do
          connection = ActiveRecord::Base::connection
          begin
            connection.drop_table "physicians"
            connection.drop_table "appointments"
            connection.drop_table "patients"
          rescue
            p "Unable to drop tables"
          end
        end
      end
    end
  end
end
