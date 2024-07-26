class BeamLotMailer < ApplicationMailer

  default from: Rails.application.credentials.croma_admin_mailid

  def cancel_lot details
    @details  = details
    mail(to: Rails.application.credentials.beam_admin_mailid, subject: 'Request to Cancel Lot')
  end

  def extend_lot details
    @details  = details
    mail(to: Rails.application.credentials.beam_admin_mailid, subject: 'Request to Extend Lot')
  end

  def email_lot_cancel(lot_id)
    lot = LiquidationOrder.with_deleted.find_by_id(lot_id)
    vendors = lot.vendor_quotation_links.pluck(:vendor_master_id)
    emails = VendorMaster.where(id: vendors).pluck(:vendor_email).compact
    emails = ['prajwalhb@blubirch.com', 'manjunathbk@blubirch.com'] if emails.blank?
    @body = "<p>Dear Sir,</p> <br> <br> This is to inform you that Lot Name: #{lot.lot_name} is been Canceled"
    mail(to: emails, subject: 'Lot Canceled')
  end

end
