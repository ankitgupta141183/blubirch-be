class Api::V1::Warehouse::InwardTrackingController < ApplicationController
  
  def index
    set_pagination_params(params)
    ird_completed_status = LookupValue.find_by(code: 'prd_status_ird_completed')
    prd_closed_status = LookupValue.find_by(code: 'prd_status_closed')
    
    prds = PendingReceiptDocument.where(status_id: ird_completed_status.id).order(id: :desc)
    prds = prds.where(inward_reference_document_number: params[:search].split_with_gsub) if params[:search].present?
    prds = prds.page(@current_page).per(@per_page)
    data = prds.collect{|prd| 
      items = prd.pending_receipt_document_items
      quantity = items.count
      qty_inwarded = items.where(status_id: prd_closed_status.id).count
      qty_not_inwarded = quantity - qty_inwarded
      { id: prd.id, inward_reference_document_number: prd.inward_reference_document_number, quantity: quantity, qty_inwarded: qty_inwarded, qty_not_inwarded: qty_not_inwarded, created_at: format_time(prd.created_at) }
    }
    
    render json: { data: data, meta: pagination_meta(prds) }
  end
  
  def show
    prd_closed_status = LookupValue.find_by(code: 'prd_status_closed')
    prd = PendingReceiptDocument.find_by(id: params[:id])
    data = prd.as_json(only: [:id, :inward_reference_document_number, :inward_reason_reference_document_number, :inward_reason_reference_document_type, :consignee_reference_document_number, :vendor_reference_document_number])
    pending_inward_items = prd.pending_receipt_document_items.where.not(status_id: prd_closed_status.id)
    data[:pending_inward_items] = pending_inward_items.as_json(only: [:id, :prd_number, :tag_number, :box_number, :sku_code, :sku_description, :quantity, :created_at])
    
    render json: { prd: data }
  end
  
  def generate_grn
    ActiveRecord::Base.transaction do
      ird_completed_status = LookupValue.find_by(code: 'prd_status_ird_completed')
      prds = PendingReceiptDocument.where(id: params[:ids], status_id: ird_completed_status.id)
      raise CustomErrors, 'Invalid ID' if prds.blank?

      prds.each do |prd|
        prd.generate_grn(current_user)
      end

      message = "GRN generated successfully for #{prds.count} IRDs!"
      render json: { message: message }
    end
  end
  
end