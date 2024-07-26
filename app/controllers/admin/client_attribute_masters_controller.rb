class Admin::ClientAttributeMastersController < ApplicationController
	before_action :set_client_attribute_master, only: [:show, :update, :destroy]

	def index
   	set_pagination_params(params)
		@client_attribute_masters = ClientAttributeMaster.filter(filtering_params).page(@current_page).per(@per_page)
		render json: @client_attribute_masters, meta: pagination_meta(@client_attribute_masters)
	end

	def show
	 render json: {attributes:@client_attribute_master , client: @client_attribute_master.client.name}
	end

	def create
	  @client_attribute_master = ClientAttributeMaster.new(client_attribute_master_params)

	  if @client_attribute_master.save
	    render json: @client_attribute_master, status: :created
	  else
	    render json: @client_attribute_master.errors, status: :unprocessable_entity
	  end
	end

	def update
	  if @client_attribute_master.update(client_attribute_master_params)
	    render json: @client_attribute_master
	  else
	    render json: @client_attribute_master.errors, status: :unprocessable_entity
	  end
	end

	def import
		@client_attribute_masters = ClientAttributeMaster.import_client_attributes(params[:file],params[:client_id])
    render json: @client_attribute_masters
	end	

	def destroy
	  @client_attribute_master.destroy
	end

	private
	
	def set_client_attribute_master
	  @client_attribute_master = ClientAttributeMaster.find(params[:id])
	end

	def client_attribute_master_params
	  params.require(:client_attribute_master).permit(:client_id, :attr_type, :reason, :attr_label, :field_type, :options, :deleted_at)
	end


	def filtering_params
	  params.slice(:client_name, :attr_type, :reason, :attr_label, :field_type, :options)
	end

end
