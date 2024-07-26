class ReturnDocument < ApplicationRecord

	acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :user, optional: true
  belongs_to :client, optional: true
  belongs_to :master_data_input, optional: true
  belongs_to :gate_pass_status, class_name: "LookupValue", foreign_key: :status_id

  has_many :return_document_inventories

end
