class Admin::CategoriesController < ApplicationController

  before_action :set_category, only: [:show, :update, :destroy]

	def index
    set_pagination_params(params)
		@categories = Category.filter(filtering_params).page(@current_page).per(@per_page)
 		render json: @categories, meta: pagination_meta(@categories)
	end

 	def show
   render json: @category
 	end

 	def create
	   @category = Category.new(name: params[:category][:name], code:params[:category][:code], attrs: [params[:category][:code]], ancestry: params[:category][:ancestry])
	  if @category.save
	    render json: @category, status: :created
	  else
	    render json: @category.errors, status: :unprocessable_entity
	  end
	end

	def get_category_parents
    @categories = Category.where(id: Category.pluck(:ancestry).compact.map { |e| e.split('/') }.flatten.uniq)
		render json: @categories
	end	

	def update
	  if @category.update(name: params[:category][:name], code:params[:category][:code], attrs: [params[:category][:code]], ancestry: params[:category][:ancestry])
	    render json: @category
	  else
	    render json: @category.errors, status: :unprocessable_entity
	  end
	end

	def import
  	@categories = Category.import_categories(params[:file])
    render json: @categories
	end	

	def destroy
	  @category.destroy
	end

  private

	def set_category
	 @category = Category.find(params[:id])
	end

	def category_params
	 params.require(:category).permit(:name, :code, :attrs, :ancestry, :deleted_at)
	end

	def filtering_params
    params.slice(:name, :code, :ancestry)
  end

end
