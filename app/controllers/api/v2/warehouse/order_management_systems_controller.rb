class Api::V2::Warehouse::OrderManagementSystemsController < ApplicationController
  skip_before_action :authenticate_user!, :check_permission, only: :tally_records
  # before_action :authenticate_invoice_token, only: [:tally_records]
  before_action :get_oms_data, only: [:index, :tally_records]
  before_action -> { set_pagination_params(params) }, only: [:index]
  before_action :set_order_management_system, only: [:show, :items, :create_invoice, :cancel_order, :print_order, :send_email_to_vendor]
  before_action :set_order_management_items, only: [:items]
  before_action :validate_order_management_items_quantity, only: [:create_invoice]

  def index
    @order_management_systems = @order_management_systems.page(@current_page).per(@per_page)
    render_collection(@order_management_systems, self.class::ORDER_SERIALIZER.constantize)
  end

  def create
    begin
      oms = ActiveRecord::Base.transaction do
        OrderManagementSystem.create_order(oms_type: self.class::OMS_TYPE, order_type: self.class::ORDER_TYPE, order_params: permitted_params)
      end
      render_success_message("New #{self.class::ORDER_TYPE.titleize} \"#{oms.reason_reference_document_no}\" has been successfully generated", 200)
    rescue => e
      render_error(e.message, 500)
    end
  end

  def show
    render_resource(@order_management_system, self.class::ORDER_SERIALIZER.constantize)
  end

  def items
    render_collection(@order_management_items, self.class::ORDER_ITEM_SERIALIZER.constantize)
  end

  def tally_records
    return render_error("No Records Available", 404) if @order_management_systems.blank?
    records = self.class::TALLY_SERVICE_PATH.constantize.get_records(data: @order_management_systems)
    render json: { response: records }, status: 200
  end

  def item_details
    return render_error("Missing 'search_value' in params.", 500) unless params[:search_value].present?
    inventory = ClientSkuMaster.find_by("code = :search_value OR sku_description = :search_value", search_value: params[:search_value])
    return render_error("Data not found with given search value \"#{params[:search_value]}\"", 500) unless inventory
    render json: { article_id: inventory.code, article_description: inventory.sku_description, price: inventory.mrp }, status: 200
  end
  
  def create_invoice
    begin
      invoice_no = ActiveRecord::Base.transaction do
        @order_management_system.create_invoice(params[:items], self.class::ORDER_TYPE)
      end
      render_success_message("Invoice \'#{invoice_no}\' created successfully for #{params[:items].size} items", 200)
    rescue => e
      render_error(e.message, 500)
    end
  end

  def cancel_order
    begin
      ActiveRecord::Base.transaction do
        @order_management_system.update(status: "cancel")
      end
      render_success_message("#{self.class::ORDER_TYPE.titleize} '#{@order_management_system.reason_reference_document_no}' has been successfully canceled", 200)
    rescue => e
      render_error(e.message, 500)
    end
  end

  def print_order
    begin
      ActiveRecord::Base.transaction do 
        print_data = OrderManagementSystem.get_print_data(@order_management_system)
      end
      render_success_message("print order for the #{self.class::ORDER_TYPE} '#{@order_management_system.reason_reference_document_no}' successfull.", 200)
    rescue => e
      render_error(e.message, 500)
    end
  end

  def send_email_to_vendor
    begin
      ActiveRecord::Base.transaction do 
        vendor = ClientProcurementVendor.find_by(@order_management_system.vendor_id)

        OmsEmailWorker.perform_async(@order_management_system, vendor)
      end
      render_success_message("Email successfully sent for this #{@order_management_system.reason_reference_document_no} order.", 200)
    rescue => e
      render_error(e.message, 500)
    end
  end


  private

  def get_oms_data
    query = ["oms_type = '#{self.class::OMS_TYPE}' AND order_type = '#{self.class::ORDER_TYPE}'"]
    if params['start_date'].present? && params['end_date'].present?
      query[0] += " AND DATE(created_at) BETWEEN '#{params['start_date'].to_date}' AND '#{params['end_date'].to_date}'"
    end
    @order_management_systems = OrderManagementSystem.includes(:order_management_items).where(query)
  end

  def authenticate_invoice_token
    client_token = ClientToken.find_by(integration_name: params[:integration_name])
    client_token&.update_last_used
    render_error("Not Authorized", 401) unless client_token&.api_token == request.headers['Authorization']&.split(' ').try(:last)
  end

  def set_order_management_system
    @order_management_system = OrderManagementSystem.find_by(id: params[:id])
    render_error("OMS with ID \'#{params[:id]}\' could not found.", 422) if @order_management_system.blank?
  end

  def set_order_management_items
    @order_management_items = @order_management_system.order_management_items
    render_error("No item found.", 422) if @order_management_items.blank?
  end

  def validate_order_management_items_quantity
    params[:items].each do |item|
      omi = @order_management_system.order_management_items.find_by(id: item[:id])
      if omi&.quantity.to_i < item[:quantity].to_i
        render_error("Qauntity \'#{item[:quantity]}\' is not available for \'#{omi.sku_code}\'", 422) and return
      end
    end
  end
end
