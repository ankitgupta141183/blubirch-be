class GatePassBox < ApplicationRecord
	acts_as_paranoid
  belongs_to :gate_pass, optional: true
  belongs_to :packaging_box, optional: true
  belongs_to :user, optional: true

end
