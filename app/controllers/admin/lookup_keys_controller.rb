class Admin::LookupKeysController < ApplicationController

  before_action :set_lookup_key, only: [:show, :update, :destroy]

	def index
      set_pagination_params(params)
      @lookup_keys = LookupKey.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
      unless params[:page]
        @lookup_keys = @lookup_keys.per(LookupKey.count)
      end
      render json: @lookup_keys, meta: pagination_meta(@lookup_keys)
  end

	def show
  	render json: @lookup_key
	end

	def create
  	@lookup_key = LookupKey.new(lookup_key_params)

  	if @lookup_key.save
  		render json: @lookup_key, status: :created
  	else
    	render json: @lookup_key.errors, status: :unprocessable_entity
  	end
	end

  def edit
    render json: @lookup_key
  end

	def update
  	if @lookup_key.update(lookup_key_params)
    	render json: @lookup_key
  	else
    	render json: @lookup_key.errors, status: :unprocessable_entity
  	end
	end

	def destroy
  	@lookup_key.destroy
	end

  def import 
    @lookup_keys = LookupKey.import(params[:file])
    render json: @lookup_keys
  end

	private
  # Use callbacks to share common setup or constraints between actions.
  def set_lookup_key
    @lookup_key = LookupKey.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def lookup_key_params
    params.require(:lookup_key).permit(:name, :code, :deleted_at)
  end

  def filtering_params
    params.slice(:name, :code)
  end

end
