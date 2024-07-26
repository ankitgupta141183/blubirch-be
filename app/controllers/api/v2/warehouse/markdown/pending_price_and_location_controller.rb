class Api::V2::Warehouse::Markdown::PendingPriceAndLocationController < Api::V2::Warehouse::MarkdownsController
  STATUS = 'Pending Transfer Out Destination'

  before_action :check_for_update_markdown_params, :set_markdowns, only: :update_markdowns

  def update_markdowns
    markdown_dispatch_status = LookupValue.find_by(code: Rails.application.credentials.markdown_status_pending_markdown_dispatch)
    distribution_center_id = DistributionCenter.find_by(code: params[:markdown][:markdown_location])&.id
    warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick)
    markdown_order = create_markdown_order
    warehouse_order = create_warehouse_order(markdown_order, distribution_center_id, warehouse_order_status)
    @markdowns.each do |markdown|
      update_markdown(markdown, markdown_dispatch_status, markdown_order.id, distribution_center_id)
      client_category = markdown.inventory.client_category rescue nil
      create_warehouse_order_item(markdown, warehouse_order, warehouse_order_status, client_category)
    end
    render_success_message("Items move to Dispatch successfully!", :ok)
  end

  private

  def create_markdown_order
    MarkdownOrder.create(vendor_code: params[:markdown][:markdown_location], order_number: "OR-PTO-#{SecureRandom.hex(6)}")
  end

  def update_markdown(markdown, markdown_dispatch_status, markdown_order_id, distribution_center_id)
    markdown.details["markdown_price"] = markdown.asp.to_f == 0 ? 0 : (markdown.asp.to_f - ( params[:markdown][:markdown_discount].to_f * markdown.asp.to_f/100 ))
    markdown.details["markdown_discount"] = params[:markdown][:markdown_discount]
    markdown.update({status_id: markdown_dispatch_status.id, status: markdown_dispatch_status.original_code, destination_code: params[:markdown][:markdown_location], markdown_order_id: markdown_order_id, distribution_center_id: distribution_center_id})
    markdown_history = markdown.markdown_histories.new(status_id: markdown.status_id)
    markdown_history.details = {}
    markdown_history.details["pending_markdown_destination_created_at"] = Time.now.to_s
    markdown_history.details["status_changed_by_user_id"] = current_user.id
    markdown_history.details["status_changed_by_user_name"] = current_user.full_name
    markdown_history.save
  end

  def create_warehouse_order(markdown_order, distribution_center_id, warehouse_order_status)
    client_id = params[:markdown][:client_id] rescue nil
    markdown_order.warehouse_orders.create(distribution_center_id: distribution_center_id, status_id:  warehouse_order_status.id, total_quantity: @markdowns.count, vendor_code: params[:markdown][:markdown_location], client_id: client_id, reference_number: markdown_order.order_number)
  end

  def create_warehouse_order_item(markdown, warehouse_order, warehouse_order_status, client_category)
    warehouse_order_item = warehouse_order.warehouse_order_items.new(inventory_id: markdown.inventory.id, sku_master_code: markdown.sku_code, item_description: markdown.item_description, tag_number: markdown.tag_number, quantity: 1, status_id: warehouse_order_status.id, status: warehouse_order_status.original_code, serial_number: markdown.inventory.serial_number)
    warehouse_order_item.client_category_id = client_category.id rescue nil
    warehouse_order_item.client_category_name = client_category.name rescue nil
    warehouse_order_item.details = markdown.inventory.details
    warehouse_order_item.save
  end

  def check_for_update_markdown_params

    render_error('Required params "markdown" is missing!', :unprocessable_entity) and return if params[:markdown].blank?

    render_error('Required params "markdown_ids" is missing!', :unprocessable_entity) and return if params[:markdown][:ids].blank?

    render_error('Markdown Price or markdown Discount is missing', :unprocessable_entity) and return if params[:markdown][:markdown_price].blank? || params[:markdown][:markdown_discount].blank?
    
    render_error('Markdown Location is missing', :unprocessable_entity) and return if params[:markdown][:markdown_location].blank?
  end

end
