class Admin::ClientSkuMastersController < ApplicationController
	before_action :set_client_sku_master, only: [:show, :update, :destroy]

	def index
   set_pagination_params(params)
   @client_sku_masters = ClientSkuMaster.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
   render json: @client_sku_masters, meta: pagination_meta(@client_sku_masters)
	end

 	def show
   render json: @client_sku_master
 	end

 	def create
	   @client_sku_master = ClientSkuMaster.new(client_sku_master_params)
	  if @client_sku_master.save
	    render json: @client_sku_master, status: :created
	  else
	    render json: @client_sku_master.errors, status: :unprocessable_entity
	  end
	end

	def update
	  if @client_sku_master.update(client_sku_master_params)
	    render json: @client_sku_master
	  else
	    render json: @client_sku_master.errors, status: :unprocessable_entity
	  end
	end

	def destroy
	  @client_sku_master.destroy
	end

  def import
    ClientSkuMaster.import(params[:file])
    redirect_to  admin_client_sku_masters_path, notice: "Client SKU Masters Imported"
  end

  private

	def set_client_sku_master
	 @client_sku_master = ClientSkuMaster.find(params[:id])
	end

	def client_sku_master_params
	 params.require(:client_sku_master).permit(:client_category_id, :code, :description, :deleted_at)
	end

	def filtering_params
    params.slice(:code, :client_category_id)
  end
end
