class Api::V1::Store::GatePassSerializer < ActiveModel::Serializer
  
  attributes :id, :gatepass_number, :box_count, :rr_number, :return_reason, :destination, :boxes

  belongs_to :distribution_center
  belongs_to :client

  def box_count
    object.gate_pass_boxes.size
  end

  def rr_number
    object.packaging_boxes.last.details['return_request_number'] rescue ''
  end

  def return_reason
    rr = ReturnRequest.find_by(request_number: object.packaging_boxes.last.details['return_request_number']) rescue ''
    return rr.details['customer_return_reason'] rescue ''
  end

  def destination
    rr = ReturnRequest.find_by(request_number: object.packaging_boxes.last.details['return_request_number']) rescue ''
    return rr.client.address rescue ''
  end

  def boxes
    object.packaging_boxes
  end

end