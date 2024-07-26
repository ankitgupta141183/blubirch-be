class ConsignmentBox < ApplicationRecord
	acts_as_paranoid
  belongs_to :consignment_gate_pass
  belongs_to :distribution_center
  belongs_to :logistics_partner
  has_many :box_details
  has_many :consignment_box_files
  accepts_nested_attributes_for :consignment_box_files
end
