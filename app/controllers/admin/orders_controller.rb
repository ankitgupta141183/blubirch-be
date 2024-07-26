class Admin::OrdersController < ApplicationController

	before_action :set_order, only: [:show, :update, :destroy, :edit]

  def index
    set_pagination_params(params)
    @orders = Order.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @orders, meta: pagination_meta(@orders)
  end

  def show
    render json: @order
  end

  def create
		@order = Order.new(order_params)
		if @order.save
			render :json => @order
		else
			render json: @order.errors, status: :unprocessable_entity
		end
	end

  def edit
    render json: @order
  end

  def update
    if @order.update(order_params)
      render json: @order
    else
      render json: @order.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @order.destroy
  end

  def import 
    @orders = Order.import(params[:file])
    render json: @orders
  end

	private

	def order_params
    params.require(:order).permit(:client_id, :user_id, :order_number, :order_type_id, :from_address, :to_address)
  end

  def set_order
    @order = Order.find(params[:id])
  end

  def filtering_params
    params.slice(:client_id,:user_id, :order_type_id, :order_number)
  end

end
