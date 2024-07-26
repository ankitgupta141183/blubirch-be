class Api::V1::Warehouse::ConsignmentBoxSerializer < ActiveModel::Serializer

  attributes :id, :consignment_gate_pass, :vendor_name, :box_count, :received_box_count, :delivery_date, :transporter_name, :gate_pass_boxes, :gate_pass_number, :consignment_name, :city_name

  has_many :box_details
  
  def vendor_name
    object.distribution_center.name rescue nil
  end

  def transporter_name
    object.logistic_partner.name rescue nil
  end

  def gate_pass_boxes
    object.consignment_gate_pass.gate_pass.packaging_boxes.collect(&:box_number) rescue nil
  end

  def gate_pass_number
    object.consignment_gate_pass.gate_pass.gatepass_number rescue nil
  end

  def consignment_name
    (object.consignment_gate_pass.gate_pass.gatepass_number + " " + object.distribution_center.name) rescue nil
  end

  def city_name
    object.distribution_center.city.original_code rescue nil
  end

end
