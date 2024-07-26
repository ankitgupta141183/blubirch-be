class Admin::ClientCategoriesController < ApplicationController

  before_action :set_client_category, only: [:show, :update, :destroy]

	def index
		set_pagination_params(params)
  	@client_categories = ClientCategory.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
  	render json: @client_categories, meta: pagination_meta(@client_categories)
	end

 	def show
   render json: @client_category
 	end

 	def create
	   @client_category = ClientCategory.new(name: params[:client_category][:name], client_id: params[:client_category][:client_id], code:params[:client_category][:code], attrs: [params[:client_category][:code]], ancestry: params[:client_category][:ancestry])

	  if @client_category.save
	    render json: @client_category, status: :created
	  else
	    render json: @client_category.errors, status: :unprocessable_entity
	  end
	end

	def get_client_category_parents
    @client_categories = ClientCategory.where(id: ClientCategory.pluck(:ancestry).compact.map { |e| e.split('/') }.flatten.uniq)
		render json: @client_categories
	end

	def import
    @client_categories = ClientCategory.import_client_categories(params[:file],params[:client_id])
    render json: @client_categories
	end	

	def get_all_client_category
    @client_categories = ClientCategory.all
    render json: @client_categories
	end	



	def update
	  if @client_category.update(name: params[:client_category][:name], client_id: params[:client_category][:client_id], code:params[:client_category][:code], attrs: [params[:client_category][:code]], ancestry: params[:client_category][:ancestry])

	    render json: @client_category
	  else
	    render json: @client_category.errors, status: :unprocessable_entity
	  end
	end

	def destroy
	  @client_category.destroy
	end

  private

	def set_client_category
	 @client_category = ClientCategory.find(params[:id])
	end

	def client_category_params
	 params.require(:client_category).permit(:client_id, :name, :code, :attrs, :ancestry, :deleted_at)
	end

	def filtering_params
    params.slice(:name, :client_id, :code, :ancestry)
  end
end
