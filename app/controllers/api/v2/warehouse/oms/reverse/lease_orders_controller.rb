class Api::V2::Warehouse::Oms::Reverse::LeaseOrdersController < Api::V2::Warehouse::OrderManagementSystemsController
	OMS_TYPE = 'reverse'
	ORDER_TYPE = 'lease_order'
	ORDER_SERIALIZER = 'Api::V2::Warehouse::Oms::Reverse::LeaseOrdersSerializer'
	ORDER_ITEM_SERIALIZER = 'Api::V2::Warehouse::Oms::Reverse::LeaseOrderItemsSerializer'
	TALLY_SERVICE_PATH = 'Tally::OutwardLeaseOrderService'

	def show
		super
	end

	def items
		super
	end

	def cancel_order
		super
	end

	def vendor_details
		vendor_details = ClientProcurementVendor.select(:id, :vendor_name)
		render json: { vendor_details: vendor_details }, status: 200
	end

	def location_details
		location_details = DistributionCenter.select(:id, :name)
		render json: { location_details: location_details }, status: 200
	end

	def article_id_list
		article_ids = ClientSkuMaster.pluck(:code).uniq.compact.sort
		render json: { article_ids: article_ids }, status: 200
	end

	def article_description_list
		article_items = ClientSkuMaster.pluck(:sku_description).uniq.compact.sort
		render json: { article_items: article_items }, status: 200
	end

	def item_details
    return render_error("Missing 'search_value' in params.", 500) unless params[:search_value].present?
    inventory = ClientSkuMaster.find_by("code = :search_value OR sku_description = :search_value", search_value: params[:search_value])
    return render_error("Data not found with given search value \"#{params[:search_value]}\"", 500) unless inventory
    render json: { article_id: inventory.code, article_description: inventory.sku_description, price: inventory.mrp }, status: 200
  end

	def tally_records
		super
	end

	def print_order
		super
	end

	private

	def permitted_params
    params.require(:lease_order).permit(:receiving_location_id, :billing_location_id, :vendor_id, :amount, :order_reason, :has_payment_terms, :remarks, :terms_and_conditions, items: [:sku_code, :item_description, :price, :quantity, :total_price, :inventory_id], payment_term_details: {})
  end
end
