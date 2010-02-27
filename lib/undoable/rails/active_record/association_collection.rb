module Undoable::Rails::ActiveRecord::AssociationCollection

  def self.included(klass)
    klass.class_eval do

      unless method_defined?("<<_with_undo_transaction".to_sym)
        send(:define_method, "<<_with_undo_transaction".to_sym) do |*records|
          if (@owner.is_a?(Undoable::Models::Reverse) && !@owner.new_record?)
            @owner.class.send(:create_undo_records, Undoable::Models::Update.to_s.demodulize, @owner)
          end
          send("<<_without_undo_transaction".to_sym, records)
        end

        send(:alias_method_chain, :<<, :undo_transaction)
      end
    end
  end
end                                                                                                                     
