class Api::V1::Warehouse::GatePassSerializer < ActiveModel::Serializer

  attributes :id, :created_at, :gatepass_number, :received_boxes, :warehouse, :vendor_name, :vendor_id, :receipt_date, :transporter_name, :transporter_id, :box_count, :inventory_count

  def vendor_name
    object.distribution_center.name rescue nil
  end

  def vendor_id
    object.distribution_center.id rescue nil
  end

  def received_boxes
    object.gate_pass_boxes.size rescue nil
  end

  def warehouse
    object.distribution_center.city.original_code
  end

  def receipt_date
    object.consignment_gate_pass.consignment.created_at.strftime("%d-%m-%Y") rescue nil
  end

  def transporter_name
    object.consignment_gate_pass.consignment.logistics_partner.name rescue nil
  end

  def transporter_id
    object.consignment_gate_pass.consignment.logistics_partner.id rescue nil
  end

  def box_count
    object.gate_pass_boxes.size rescue nil
  end

  def inventory_count
    total_count = 0
    object.gate_pass_boxes.each do |box|
      total_count += box.packaging_box.packed_inventories.size rescue nil
    end
    return total_count
  end

end
