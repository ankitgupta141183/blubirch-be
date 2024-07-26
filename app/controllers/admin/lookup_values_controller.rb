class Admin::LookupValuesController < ApplicationController

	before_action :set_lookup_value, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @lookup_values = LookupValue.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @lookup_values, meta: pagination_meta(@lookup_values)
  end

  def show
   	render json: @lookup_value
  end

	def create
  	@lookup_value = LookupValue.new(lookup_value_params)
  	if @lookup_value.save
    	render json: @lookup_value, status: :created
  	else
    	render json: @lookup_value.errors, status: :unprocessable_entity
 	 	end
	end

	def update
  	if @lookup_value.update(lookup_value_params)
    	render json: @lookup_value
  	else
    	render json: @lookup_value.errors, status: :unprocessable_entity
  	end
	end

	def destroy
  	@lookup_value.destroy
	end

  def import 
    @lookup_values = LookupValue.import(params[:file])
    render json: @lookup_values, status: :created
  end

  def search
    set_pagination_params(params)
    if params[:search_params]
      parameter = params[:search_params].downcase
      @search_results = LookupValue.all.where("lower(code) LIKE :search_params", search_params: "%#{parameter}%").page(@current_page).per(@per_page)
      render json: @search_results, meta: pagination_meta(@search_results)
    else
      render json: @search_results.errors, status: :unprocessable_entity
    end
  end

  def get_lookup_value_parents
    @lookup_values = LookupValue.where(id: LookupValue.pluck(:ancestry).compact.map { |e| e.split('/') }.flatten.uniq)
    render json: @lookup_values
  end

	private
  # Use callbacks to share common setup or constraints between actions.
	def set_lookup_value
  	@lookup_value = LookupValue.find(params[:id])
	end

  # Only allow a trusted parameter "white list" through.
	def lookup_value_params
  	params.require(:lookup_value).permit(:code, :position, :ancestry, :original_code, :deleted_at, :lookup_key_id)
	end

  def filtering_params
    params.slice(:lookup_key_id, :ancestry, :code, :original_code, :is_paginate)
  end

end
