class Api::V2::Warehouse::Oms::Reverse::BackOrdersController < Api::V2::Warehouse::OrderManagementSystemsController
	OMS_TYPE = 'reverse'
	ORDER_TYPE = 'back_order'
	ORDER_SERIALIZER = 'Api::V2::Warehouse::Oms::Reverse::BackOrdersSerializer'
	ORDER_ITEM_SERIALIZER = 'Api::V2::Warehouse::Oms::Reverse::BackOrderItemsSerializer'
	TALLY_SERVICE_PATH = 'Tally::OutwardBackOrderService'

	def show 
		super
	end

	def items
		super
	end

	def cancel_order
		super
	end

	def tally_records
		super
	end

	def item_details
		super
	end

  def print_order
    super
  end

	def move_to_so
		@back_order = OrderManagementSystem.find_by(id: params[:id])

		if @back_order.order_management_items.present?

			sale_order_params = { 
				receiving_location_id: @back_order&.receiving_location_id,
				billing_location_id: @back_order&.billing_location_id,
				vendor_id: @back_order&.vendor_id,
			 	amount: @back_order&.amount, 
				order_reason: @back_order&.order_reason,
				has_payment_terms: @back_order&.has_payment_terms,
				remarks: @back_order&.remarks,
				terms_and_conditions: @back_order&.terms_and_conditions,
				payment_term_details: @back_order&.payment_term_details,
				items: @back_order.order_management_items.map do |item|
        	{
    				sku_code: item.sku_code,
    				item_description: item.item_description,
    				price: item.price,
    				quantity: item.quantity,
    				total_price: item.total_price,
    				status: item.status
  				}
        end
       }
			OrderManagementSystem.create_order(oms_type: 'reverse', order_type: 'back_order', order_params: sale_order_params)

			@back_order.destroy

			render_success_message("BackOrder Moved to SaleOrder Sucessfully.", 200)
		else
			render_error("\"#{@back_order.reason_reference_document_no}\"  cannot be moved to SO since the inventory in saleable module is insufficient.", 500)
		end
	end

	private

	def permitted_params
		params.require(:back_orders).permit(:receiving_location_id, :billing_location_id, :vendor_id, :amount, :order_reason, :has_payment_terms, :remarks, :terms_and_conditions, items: [:sku_code, :item_description, :price, :quantity, :total_price, :status], payment_term_details: {})
	end
end
