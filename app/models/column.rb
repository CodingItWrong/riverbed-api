class Column < ApplicationRecord
  belongs_to :board
  belongs_to :user # direct user reference necessary for JR
end
