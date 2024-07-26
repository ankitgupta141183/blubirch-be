class Api::V1::LookupsController < ApplicationController

	def inventory_store_status
    @lookup_key = LookupKey.where(code: "INV_STS_STORE").first
    render json: @lookup_key
  end

  def inventory_warehouse_status
    @lookup_key = LookupKey.where(code: "INV_STS_WAREHOUSE").first
    render json: @lookup_key
  end

  def logistics_order_types
    @lookup_key = LookupKey.where(code: "LOGISTICS_ODR_TYPES").first
    render json: @lookup_key
  end

  def country
    @lookup_key = LookupKey.where(code: "CTRY").first
    render json: @lookup_key
  end

  def states
    @lookup_key = LookupKey.where(code: "STATE").first
    render json: @lookup_key
  end

  def cities
    @lookup_key = LookupKey.where(code: "CITY").first
    render json: @lookup_key
  end

  def get_child_values
    @lookup_value = LookupValue.where(id: params[:parent_id]).first.children
    render json: @lookup_value
  end

  def get_email_templates
    @lookup_value = LookupKey.where(code: "EMAIL_TEMPLATES").first.lookup_values
    render json: @lookup_value
  end

  def get_distribution_center_types
    @lookup_value = LookupKey.where(code: "DISTRIBUTION_CNT_TYPES").first.lookup_values
    render json: @lookup_value
  end

  def get_dealer_types
    @lookup_value = LookupKey.where(code: "DEALER_TYPES").first.lookup_values
    render json: @lookup_value
  end


  def reminder_status
    @lookup_key = LookupKey.where(code: ["INV_STS_STORE", "INV_STS_WAREHOUSE"])
    render json: @lookup_key
  end

  def get_customer_return_reasons
    @return_reasons = CustomerReturnReason.all
    render json: @return_reasons
  end

  def get_warehouse_reasons
    @lookup_value = LookupKey.where(code: "WAREHOUSE_REASONS").first.lookup_values
    render json: @lookup_value
  end

  def get_client_categories
    @client_categories = ClientCategory.all
    render json: @client_categories
  end 

  def get_client_sku_masters
    @client_sku_masters = ClientSkuMaster.all
    render json: @client_sku_masters
  end

  def get_payment_types
    @lookup_value = LookupKey.where(code: "INVOICE_PAYMENT_TYPES").first.lookup_values
    render json: @lookup_value
  end

end
