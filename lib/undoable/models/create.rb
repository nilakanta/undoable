module Undoable::Models
  class Create < Operation                                                                                    
    def undo
      un_create
    end
  end
end