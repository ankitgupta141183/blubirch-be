class Api::V1::Store::InvoicesController < ApplicationController

	def fetch_inventories
		@invoice = Invoice.includes(:distribution_center, :client, invoice_inventory_details: [:client_category, :client_sku_master]).where("LOWER(invoice_number) = ?", params[:invoice_number].downcase).references(:invoice_inventory_details, :client, :distribution_center).first
		render json: @invoice
	end

  def save_inventories
    invoice = Invoice.includes(:return_requests).where("invoices.id = ?", params[:no_grade_inventory][:invoice_id]).references(:return_requests).first
    status, result = ReturnRequest.create_inventories(invoice, params[:no_grade_inventory][:selected_inventories], params[:no_grade_inventory][:customer_return_reason_id], current_user)
    if status == true
      render json: result, adapter: :json
    else
      render json: result, status: :unprocessable_entity
    end
  end
  

  def get_return_reasons
    pending_approval_status = LookupValue.where(code: "inv_sts_store_pending_approval").first
    approved_reasons = ReturnRequest.where("details ->> 'invoice_number' = ? and status_id != ?", params[:invoice_number], pending_approval_status.try(:id)).collect(&:details).map {|c| c["customer_return_reason"]}
    if approved_reasons.blank?
      @return_reasons = CustomerReturnReason.all
    else
      @return_reasons = CustomerReturnReason.where("name not in (?)", approved_reasons)
    end
    render json: @return_reasons
  end

  def fetch_invoice_inventories
    set_pagination_params(params)
    if params[:sku_code].blank?
      @inventories = Invoice.where("invoice_number = ?", params[:invoice_number]).first.invoice_inventory_details.page(@current_page).per(@per_page)
    else
      @inventories = Invoice.where("invoice_number = ?", params[:invoice_number]).first.invoice_inventory_details.where("details ->> 'product_code_sku' = ?", params["sku_code"]).page(@current_page).per(@per_page)
    end
    render json: @inventories, meta: pagination_meta(@inventories)
  end

  def no_grade_inventory
    invoice = Invoice.find(params[:no_grade_inventory][:invoice_id])
    selected_reason = CustomerReturnReason.find(params[:no_grade_inventory][:return_reason_id])
    no_grade_inventories = invoice.invoice_inventory_details.where("id in (?)", (params[:no_grade_inventory][:selected_inventory]).map {|inv| inv["id"]})
    pending_approval_status = LookupValue.where(code: "inv_sts_store_pending_approval").first
    return_request = ReturnRequest.where("details ->> 'invoice_number' = ? and details ->> 'customer_return_reason' = ? and status_id != ?", invoice.details["invoice_number"], invoice.details["customer_return_reason"], pending_approval_status.try(:id)).last
    if return_request.blank?
      inv_grade_not_tested = LookupValue.where(code: "inv_grade_not_tested").first
      total_inventories = 0
      return_request_number = "R-#{SecureRandom.hex(3)}"
      if no_grade_inventories.present?
        (params[:no_grade_inventory][:selected_inventory]).each do |inv|
          invoice_inventory_detail = InvoiceInventoryDetail.find(inv["id"])
          quantity = ((invoice_inventory_detail.quantity - inv["return_quantity"].to_i) == 0) ? 1 : (invoice_inventory_detail.quantity - inv["return_quantity"].to_i)
          total_inventories = total_inventories + quantity

          json_details = invoice_inventory_detail.details.merge!({"return_request_number" => return_request_number, "quantity" => quantity,
                                                                  "item_price" => invoice_inventory_detail.item_price, "client_category_id" => invoice_inventory_detail.client_category_id,
                                                                  "client_sku_master_id" => invoice_inventory_detail.client_sku_master_id, "customer_return_reason" => selected_reason.name,
                                                                  "invoice_number" => invoice_inventory_detail.invoice.invoice_number, "sku" => invoice_inventory_detail.try(:cleint_sku_master).try(:code) })
          
          inventory = Inventory.new(details: invoice_inventory_detail.details.merge!({"status" => pending_approval_status.try(:original_code), "grade" => inv_grade_not_tested.try(:original_code)}),
                                    distribution_center_id: invoice.distribution_center_id, client_id: invoice.client_id, user_id: User.first.id, is_putaway_inwarded: false)
          
          inventory.inventory_statuses.build(status_id: pending_approval_status.try(:id), distribution_center_id: invoice.distribution_center_id, details: invoice_inventory_detail.details, is_active: true, user_id: @current_user.id)
          inventory.inventory_grading_details.build(grade_id: inv_grade_not_tested.try(:id), distribution_center_id: invoice.distribution_center_id, details: invoice_inventory_detail.details, is_active: true, user_id: @current_user.id)
          if inventory.save
            invoice_inventory_detail.update(return_quantity: (invoice_inventory_detail.return_quantity + quantity))
          end
        end
        return_request_details = {"total_inventories" => total_inventories, "invoice_number" => invoice.invoice_number,
                                  "customer_return_reason" => selected_reason.name}
        ReturnRequest.create(request_number: return_request_number, details: return_request_details, status_id: pending_approval_status.try(:id),
                                 distribution_center_id: invoice.distribution_center_id, client_id: invoice.distribution_center_id)
        render json:{return_request: return_request}
      else
        render json: { error: "Please select at lease one checkbox", status: 400 }, status: 400
      end
    else
      render json: { error: "Return Reason for this invoice is already sent for approval. Please selct different reason", status: 400 }, status: 400
    end
  end

end
