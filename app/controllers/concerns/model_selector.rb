module ModelSelector
  extend ActiveSupport::Concern

  def find_model(disposition, is_forward = false)
    case disposition
    when 'Brand Call-Log'
      model = BrandCallLog
    when 'Redeploy'
      model = Redeploy
    when 'Repair'
      model = Repair
    when 'Replacement'
      model = if is_forward.present?
        ForwardReplacement
      else
        Replacement
      end
    when 'E-Waste'
      model = EWaste
    when 'Liquidation'
      model = Liquidation
    when 'Insurance'
      model = Insurance
    when 'RTV'
      model = VendorReturn
    when 'Pending Transfer Out'
      model = Markdown
    when 'Pending Disposition'
      model = PendingDisposition
    when 'Restock'
      model = Restock
    when 'Capital Assets'
      model = CapitalAsset
    when 'Markdown'
      model = Markdown
    when 'Saleable'
      model = Saleable
    when 'Production'
      raise 'Module is not implemented'
    when 'Usage'
      raise 'Module is not implemented'
    when 'Demo'
      model = Demo
    when 'Rental'
      model = Rental
    else
      raise 'Please pass proper Dispostion'
    end
    model
  end

  def fetch_status(disposition_id)
    key = LookupValue.find_by(id: disposition_id)
    disposition = key&.original_code
    return [] if disposition.blank?

    case disposition
    when 'Brand Call-Log'
      return LookupValue.where(code: ['brand_call_log_status_pending_information', 'brand_call_log_status_pending_bcl_ticket', 'brand_call_log_status_pending_inspection', 'brand_call_log_status_pending_decision', 'brand_call_log_status_pending_disposition']).pluck(:original_code)
    when 'Redeploy'
      code = 'REDEPLOY_STATUS'
    when 'Repair'
      return LookupValue.where(code: ['repair_status_pending_quotation', 'repair_status_pending_repair_approval', 'repair_status_pending_repair', 'repair_status_dispatch', 'repair_status_pending_disposition']).pluck(:original_code)
    when 'Replacement'
      if key.code.include?('forward')
        return LookupValue.where(code: ['forward_replacement_status_in_stock', 'forward_replacement_status_pending_payment']).pluck(:original_code)
      else
        return LookupValue.where(code: ['replacement_status_pending_confirmation', 'replacement_status_dispatch', 'replacement_status_pending_replacement']).pluck(:original_code)
      end
    when 'E-Waste'
      code = 'E-WASTE_STATUS'
    when 'Liquidation'
      return LookupValue.where(code: ['liquidation_status_pending_liquidation', 'liquidation_status_allocate_b2b', 'liquidation_status_contracted_price', 
        'liquidation_status_competitive_bidding_price', 'liquidation_status_moq_price',
        'lot_status_ready_for_publishing', 'lot_status_pending_lot_details', 'lot_status_publish_initiated', 'lot_status_publish_error', 'lot_status_ready_for_republishing', 'lot_status_creating_sub_lots',
        'liquidation_status_pending_b2c_publish', 'lot_status_in_progress_b2b', 'liquidation_status_in_progress_b2c', 'lot_status_pending_decision',
        'liquidation_status_pending_payment', 'lot_status_partial_payment', 'lot_status_full_payment_received', 'liquidation_status_pending_lot_dispatch'
      ]
      ).pluck(:original_code)
    when 'Insurance'
      return LookupValue.where(code: ['insurance_status_pending_information', 'insurance_status_pending_claim_ticket', 'insurance_status_pending_inspection', 'insurance_status_pending_decision', 'insurance_status_pending_disposition']).pluck(:original_code)
    when 'RTV'
      return LookupValue.where(code: ['vendor_return_status_pending_dispatch', 'vendor_return_status_pending_settlement']).pluck(:original_code)
    when 'Pending Transfer Out'
      code = 'MARKDOWN_STATUS'
    when 'Pending Disposition'
      code = 'PENDING_DISPOSITION_STATUS'
    when 'Restock'
      code = 'RESTOCK_STATUS'
    when 'Markdown'
      LookupValue.where(code: ['markdown_status_pending_transfer_out_destination', 'markdown_status_pending_transfer_out_dispatch']).pluck(:original_code)
    when 'Saleable'
      code = 'SALEABLE_STATUS'
    when 'Production'
      code = ''
    when 'Usage'
      code = ''
    when 'Demo'
      code = 'FORWARD_DEMO_STATUS'
    when 'Capital Assets'
      code = 'CAPITAL_ASSET_STATUS'
    when 'Rental'
      code = 'RENTAL_STATUS'
    end
    LookupKey.find_by(code: code)&.lookup_values&.pluck(:original_code)
  end
end