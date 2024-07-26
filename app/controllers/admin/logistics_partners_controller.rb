class Admin::LogisticsPartnersController < ApplicationController

	before_action :set_logistics_partner, only: [:show, :update, :destroy, :edit]

  def index
    set_pagination_params(params)
    @logistics_partners = LogisticsPartner.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @logistics_partners, meta: pagination_meta(@logistics_partners)
  end

  def show
    render json: @logistics_partner
  end

  def create
		@logistics_partner = LogisticsPartner.new(logistics_partner_params)
		if @logistics_partner.save
			render :json => @logistics_partner
		else
			render json: @logistics_partner.errors, status: :unprocessable_entity
		end
	end

  def edit
    render json: @logistics_partner
  end

  def update
    if @logistics_partner.update(logistics_partner_params)
      render json: @logistics_partner
    else
      render json: @logistics_partner.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @logistics_partner.destroy
  end

	private

	def logistics_partner_params
    params.require(:logistics_partner).permit(:name,:deleted_at)
  end

  def set_logistics_partner
    @logistics_partner = LogisticsPartner.find(params[:id])
  end

  def filtering_params
    params.slice(:name)
  end

end
