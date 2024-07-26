class ConsignmentGatePass < ApplicationRecord
	acts_as_paranoid
  belongs_to :gate_pass
  belongs_to :consignment
  
end
