class Admin::ClientCategoryMappingsController < ApplicationController
	before_action :set_client_category_mapping, only: [:show, :update, :destroy]

	def index
	 @client_category_mappings = ClientCategoryMapping.all

	 render json: @client_category_mappings
	end

	def show
	 render json: {attributes:@client_category_mapping , client: @client_category_mapping.client.name}
	end

	def create
	  @client_category_mapping = ClientCategoryMapping.new(client_category_mapping_params)

	  if @client_category_mapping.save
	    render json: @client_category_mapping, status: :created
	  else
	    render json: @client_category_mapping.errors, status: :unprocessable_entity
	  end
	end

	def update
	  if @client_category_mapping.update(client_category_mapping_params)
	    render json: @client_category_mapping
	  else
	    render json: @client_category_mapping.errors, status: :unprocessable_entity
	  end
	end

	def destroy
	  @client_category_mapping.destroy
	end

	def import 
	  @client_category_mappings = ClientCategoryMapping.import(params[:file])
	  render json: @client_category_mappings
	end

	private
	
	def set_client_category_mapping
	  @client_category_mapping = ClientCategoryMapping.find(params[:id])
	end

	def client_category_mapping_params
	  params.require(:client_category_mapping).permit(:client_id, :attr_type, :reason, :attr_label, :field_type, :options, :deleted_at)
	end

end
