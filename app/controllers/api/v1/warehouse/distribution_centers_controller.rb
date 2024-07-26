class Api::V1::Warehouse::DistributionCentersController < ApplicationController
  before_action :set_distribution_center, only: [:show, :update, :sub_location_sequence, :update_sequence]

  def index
    set_pagination_params(params)
    distribution_centers = DistributionCenter.order(updated_at: :desc)
    distribution_centers = distribution_centers.where("code ilike ?", "%#{params[:search]}%") if params[:search].present?
    distribution_centers = distribution_centers.page(@current_page).per(@per_page)
    data = []
    distribution_centers.each do |dc|
      data << {id: dc.id, code: dc.code, name: dc.name, sub_locations: dc.sub_locations.count, status: dc.is_sorted? ? "Sorted" : "Unsorted"}
    end
    
    render json: {distribution_centers: data, meta: pagination_meta(distribution_centers)}
  end

  def show
    render json: @distribution_center
  end

  def sub_location_sequence
    data = @distribution_center.as_json(only: [:id, :name, :code])
    data[:sub_locations] = @distribution_center.sub_locations.order(sequence: :asc).as_json(only: [:id, :code, :sequence])
    
    render json: {distribution_center: data}
  end
  
  def update_sequence
    sub_locations = @distribution_center.sub_locations
    params[:sub_locations].each do |sl|
      sub_location = sub_locations.find_by(id: sl[:id])
      raise CustomErrors.new "Invalid Sub Location ID." unless sub_location.present?
      
      sub_location.update!(sequence: sl[:sequence])
    end
    
    @distribution_center.update!(is_sorted: true) unless @distribution_center.is_sorted?
    render json: {status: :ok}
  end

  private
  
    def set_distribution_center
      @distribution_center = DistributionCenter.find_by(id: params[:id])
    end

    def distribution_center_params
      params.require(:distribution_center).permit()
    end
end
