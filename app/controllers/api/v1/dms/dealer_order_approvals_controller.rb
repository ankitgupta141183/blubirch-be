class Api::V1::Dms::DealerOrderApprovalsController < ApplicationController

	def dealer_order_list
		@orders = DealerOrder.where("user_id = ? and status in (?)", current_user.id, ['Edited','Pending Approval'])
		render json: @orders
	end	

	def dealer_order_item_list
		@order_items = DealerOrderItem.joins('INNER JOIN company_stocks on dealer_order_items.client_sku_master_id = company_stocks.client_sku_master_id')
		.where(dealer_order_id: params[:order_id]).select('dealer_order_items.*,company_stocks.quantity as available_quantity')
		render json: @order_items
	end


	def approve_reject_order
		@order = DealerOrder.find(params[:id])
		if params[:status] == 'Approved'
			status = LookupValue.where(code: Rails.application.credentials.dealer_order_status_approved).first
		  @order.approved_amount = params[:approved_amount]
		  @order.rejected_amount = params[:rejected_amount]
		  @order.approved_quantity = params[:approved_quantity]
		  @order.rejected_quantity = params[:rejected_quantity]
		  @order.status_id = status.id	
			@order.status = status.original_code
			@order.dealer_order_items.each do |item|
				if item.processed_quantity.blank?
					item.update(processed_quantity: item.quantity)
				end	
				company_stock = CompanyStock.where("user_id = ? and client_sku_master_id = ?", current_user.id, item.client_sku_master_id).last
				company_stock.quantity = company_stock.quantity - item.processed_quantity
				company_stock.save
			end	
		elsif params[:status] == 'Rejected'
  		status = LookupValue.where(code: Rails.application.credentials.dealer_order_status_rejected).first
  		@order.remarks =  params[:remarks]
  		@order.status_id = status.id	
			@order.status = status.original_code
		elsif params[:status] == 'Edited'
			status = LookupValue.where(code: Rails.application.credentials.dealer_order_status_edited).first
  		@order.status_id = status.id	
			@order.status = status.original_code
		end
		@order.save
		render json: @order
	end


	def update_dealer_order_item
		@order_item = DealerOrderItem.find(params[:id])
		@order_item.processed_discount_percentage = params[:discount]
		@order_item.processed_quantity = params[:processed_quantity]
		@order_item.total_amount = params[:final_amount]
		@order_item.save_status = params[:save_status]
		@order_item.save

		render json: @order_item
	end	
end
