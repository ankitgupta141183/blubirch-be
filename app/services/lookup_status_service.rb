# frozen_string_literal: true

class LookupStatusService

  attr_accessor :bucket, :step
  def initialize(bucket, step)
    @bucket = bucket
    @step = step
  end

  def call
    status_code = status_code_for_bucket
    return ['', ''] if status_code.blank?

    status = LookupValue.find_by(code: status_code)
    [status&.original_code, status&.id]
  end

  private

  def status_code_for_bucket
    case bucket

    when 'Liquidation'
      liquidation_status_code
    when 'Brand Call-Log'
      brand_call_log_status_code
    when 'Dispatch'
      dispatch_status_code
    end
  end

  def liquidation_status_code
    case step

    when 'moving_lot_creation'
      Rails.application.credentials.liquidation_status_pending_rfq_status
    when 'create_lots'
      Rails.application.credentials.liquidation_status_pending_publish_status
    when 'create_beam_lots'
      Rails.application.credentials.liquidation_status_pending_publish_status
    when 'update_lot_beam_status'
      Rails.application.credentials.liquidation_status_inprogress_status
    when 'create_bids'
      Rails.application.credentials.liquidation_status_decision_pending_status
    when 'buy_bids'
      Rails.application.credentials.liquidation_status_pending_payment
    when 'create_beam_republish_lots'
      Rails.application.credentials.liquidation_status_pending_publish_status
    when 'delete_lot'
      Rails.application.credentials.liquidation_pending_status
    end
  end

  def brand_call_log_status_code
    case step

    when 'pending_brand_approval'
      Rails.application.credentials.vendor_return_status_pending_brand_resolution
    when 'pending_call_log'
      Rails.application.credentials.vendor_return_status_pending_call_log
    when 'pending_brand_inspection'
      Rails.application.credentials.vendor_return_status_pending_brand_inspection
    end
  end

  def dispatch_status_code
    case step

    when 'pending_pick_and_pack'
      Rails.application.credentials.dispatch_status_pending_pick_and_pack
    when 'pending_dispatch'
      Rails.application.credentials.dispatch_status_pending_dispatch
    when 'completed'
      Rails.application.credentials.dispatch_status_completed
    end
  end
end