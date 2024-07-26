class Api::V1::Store::PendingBrandApprovalSerializer < ActiveModel::Serializer
  
  attributes :id, :request_number, :details

  belongs_to :distribution_center
  belongs_to :client
  belongs_to :return_status, class_name: "LookupValue", foreign_key: :status_id

end