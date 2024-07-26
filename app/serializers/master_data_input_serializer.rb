class MasterDataInputSerializer < ActiveModel::Serializer
  
  attributes :id, :payload, :is_error, :success_count, :failed_count, :remarks, :created_at, :updated_at, :document_number

  def document_number
    document_numbers = []
    object.payload["payload"].flatten.collect{|k| document_numbers << k["client_gatepass_number"]}.flatten.join(", ") rescue []
    document_numbers
  end

end
