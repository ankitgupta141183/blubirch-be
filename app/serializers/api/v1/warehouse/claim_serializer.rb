class Api::V1::Warehouse::ClaimSerializer < ActiveModel::Serializer
  attributes :id, :claim_number, :vendor_name, :gate_pass, :dispatch_date, :ageing, :approved_amount, :cogs, :saved_amount, :last_saved_date, :settlement_closed, :ageing_dispatch

  def vendor_name
    object.distribution_center.name
  end

  def gate_pass
    claim_status = LookupValue.find_by_code("claim_status_approved")
    claim_action_ids = object.claim_actions.where(status_id: claim_status.id).pluck(:id)
    object.vendor_returns.where(claim_action_id: claim_action_ids).last.inventory.packed_inventory.packaging_box.gate_passes.last.gatepass_number rescue ''
  end

  def dispatch_date
    claim_status = LookupValue.find_by_code("claim_status_approved")
    claim_action_ids = object.claim_actions.where(status_id: claim_status.id).pluck(:id)
    object.vendor_returns.where(claim_action_id: claim_action_ids).last.inventory.packed_inventory.packaging_box.gate_passes.last.consignment_gate_pass.consignment.created_at.strftime("%d/%m/%Y") rescue ''
  end

  def ageing
    "#{(Date.today.to_date - object.created_at.to_date).to_i} d" rescue "0 d"
  end

  def ageing_dispatch
    claim_status = LookupValue.find_by_code("claim_status_approved")
    claim_action_ids = object.claim_actions.where(status_id: claim_status.id).pluck(:id)
    "#{(Date.today.to_date - object.vendor_returns.where(claim_action_id: claim_action_ids).last.inventory.packed_inventory.packaging_box.gate_passes.last.consignment_gate_pass.consignment.created_at.to_date).to_i} d" rescue "0 d"
  end

  def approved_amount
    pending_status = LookupValue.find_by_code('claim_settlement_status_open')
    closed_status = LookupValue.find_by_code('claim_settlement_status_closed')
    if (object.rtv_settlements.find_by_status_id(closed_status.id).present? rescue false)
      amount = object.rtv_settlements.where(status_id: closed_status.id).last.approved_amount rescue "0.0"
    else
      amount = object.rtv_settlements.where(status_id: pending_status.id).last.approved_amount rescue "0.0"
    end
    amount
  end

  def saved_amount
    pending_status = LookupValue.find_by_code('claim_settlement_status_open')
    closed_status = LookupValue.find_by_code('claim_settlement_status_closed')
    if (object.rtv_settlements.find_by_status_id(closed_status.id).present? rescue false)
      amount = object.rtv_settlements.find_by_status_id(closed_status.id).saved_amount rescue "0.0"
    else
      amount = object.rtv_settlements.where(status_id: pending_status.id).last.saved_amount rescue "0.0"
    end
    amount
  end

  def settlement_closed
    closed_status = LookupValue.find_by_code('claim_settlement_status_closed')
    (object.rtv_settlements.find_by_status_id(closed_status.id).present? rescue false)
  end

  def cogs
    total = 0
    claim_status = LookupValue.find_by_code("claim_status_approved")
    claim_action_ids = object.claim_actions.where(status_id: claim_status.id).pluck(:id)
    object.vendor_returns.where(claim_action_id: claim_action_ids).each do |vr|
      total += vr.details['item_price'].to_f
    end
    total
  end

  def last_saved_date
    pending_status = LookupValue.find_by_code('claim_settlement_status_open')
    closed_status = LookupValue.find_by_code('claim_settlement_status_closed')
    if (object.rtv_settlements.find_by_status_id(closed_status.id).present? rescue false)
      object.rtv_settlements.find_by_status_id(closed_status.id).created_at.strftime("%d/%m/%Y") rescue ''
    else
      object.rtv_settlements.find_by_status_id(pending_status.id).created_at.strftime("%d/%m/%Y") rescue ''
    end
  end

end
