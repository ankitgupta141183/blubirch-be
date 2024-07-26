class Api::V2::Warehouse::Oms::Reverse::OutwardReturnOrdersController < Api::V2::Warehouse::OrderManagementSystemsController
	OMS_TYPE = 'reverse'
	ORDER_TYPE = 'outward_return_order'
	ORDER_SERIALIZER = 'Api::V2::Warehouse::Oms::Reverse::OutwardReturnOrdersSerializer'
	ORDER_ITEM_SERIALIZER = 'Api::V2::Warehouse::Oms::Reverse::OutwardReturnOrderItemsSerializer'
	TALLY_SERVICE_PATH = 'Tally::OutwardReturnOrderService'

	def index
		super
	end

	def show
		super
	end

	def create
		super
	end		

	def item 
		super
	end

	def tally_records
		super
	end

	def item_details
		super
	end

	def cancel_order
		super
	end

	def print_order
		super
	end

	private

	def permitted_params
		params.require(:outward_return_order).permit(:receiving_location_id, :billing_location_id, :vendor_id, :order_reason, :has_payment_terms, :remarks, :terms_and_conditions, items:[:sku_code, :item_description, :price, :quantity, :total_price], payment_term_details:{})
	end
end
