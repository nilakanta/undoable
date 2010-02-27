module Undoable::Models

  class Destroy < Operation
    def undo
      un_destroy
    end
  end
end
