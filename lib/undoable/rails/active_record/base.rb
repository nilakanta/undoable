module Undoable::Rails::ActiveRecord::Base
  module ClassMethods
    def inherited(base)                                    
      unless (undoable_exclusions.include?(base) || self.ancestors.include?(Undoable::Models::Reverse))
        base.send(:include, Undoable::Models::Reverse) 
      end
      super(base)
    end

    def undoable_exclusions
      @undoable_exclusions ||= load_undoable_exclusions
    end

    private
    def load_undoable_exclusions
      file = undoable_exclusions_file          
      data = File.exist?(file) ? YAML.load_file(file) : {}
      custom_exclusions = [
        'Undoable::Models::UndoRecord',
        'Undoable::Models::UndoTransaction']
      custom_exclusions += (data["undoable_exclusions"] || [])
      custom_exclusions.collect{ |model| model.to_s.constantize }
    end                              
    
    def undoable_exclusions_file
      File.join(RAILS_ROOT, 'config', 'undoable_exclusions.yml')      
    end    
  end

  def self.included(klass)
    klass.extend ClassMethods

    klass.class_eval do
      cattr_accessor :undo_transaction
    end
  end
end
