class Api::V1::Warehouse::SubLocationsController < ApplicationController
  before_action :set_sub_location, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    get_sub_locations

    @sub_locations = @sub_locations.page(@current_page).per(@per_page)
    render json: @sub_locations, meta: pagination_meta(@sub_locations)
  end
  
  def sub_location_rules
    set_pagination_params(params)
    get_sub_locations

    @sub_locations = @sub_locations.page(@current_page).per(@per_page)
    render json: @sub_locations, rules: true, meta: pagination_meta(@sub_locations)
  end

  def show
    data = @sub_location.as_json(only: [:id, :distribution_center_id, :name, :code, :category, :grade, :brand, :disposition, :return_reason])
    data[:distribution_center] = @sub_location.distribution_center&.name
    data[:location_type] = @sub_location.location_type&.titleize
    render json: {sub_location: data}
  end

  def create
    @sub_location = SubLocation.new(sub_location_params)
    existing_sub_location = @sub_location.distribution_center.sub_locations.where(code: @sub_location.code)
    raise CustomErrors.new "Sub Location has already been taken" if existing_sub_location.present?

    if @sub_location.save
      distribution_center = @sub_location.distribution_center
      distribution_center.update!(is_sorted: false)
      render json: @sub_location, status: :created
    else
      render json: {error: @sub_location.errors.full_messages}
    end
  end

  def update
    existing_sub_location = @sub_location.distribution_center.sub_locations.where(code: params[:sub_location][:code]).where.not(id: @sub_location.id)
    raise CustomErrors.new "Sub Location has already been taken" if existing_sub_location.present?
    
    if @sub_location.update(sub_location_params)
      render json: @sub_location
    else
      render json: {error: @sub_location.errors.full_messages}, status: :unprocessable_entity
    end
  end
  
  def get_locations
    if params[:have_sub_locations] == "true"
      locations = DistributionCenter.joins(:sub_locations).where("site_category in (?)", ["D", "R", "B", "E"]).distinct.as_json(only: [:id, :code])
    else
      locations = DistributionCenter.where("site_category in (?)", ["D", "R", "B", "E"]).as_json(only: [:id, :code])
    end
    location_types = SubLocation.location_types.keys.map{|k| {id: k, name: k.titleize} }
    
    render json: {locations: locations, location_types: location_types}
  end

  def bulk_delete
    SubLocation.transaction do
      sub_locations = SubLocation.where(id: params[:ids])
      inventories = Inventory.where(sub_location_id: params[:ids])
      raise CustomErrors.new "Inventories are there in these sub locations. Please move them." if inventories.present?
      
      sub_locations.each do |sub_location|
        sub_location.destroy!
      end
      render json: {status: :ok}
    end
  end
  
  def rule_types
    rules_csv = CSV.read("#{Rails.root}/public/master_files/sub_location_rules.csv", :headers=>true)
    
    categories = rules_csv['Category (L2)'].uniq.compact.map{|c| {key: c, value: c}}
    brands = rules_csv['Brand'].uniq.compact.map{|b| {key: b, value: b}}                                                            # brands = Inventory.pluck("details->'brand'").compact.uniq
    return_reasons = rules_csv['Return Reason'].uniq.compact.map{|r| {key: r, value: r}}                                            # Disposition_Rules_precedence.csv
    grades = rules_csv['Grade'].uniq.compact.map{|g| {key: g, value: g}}
    dispositions = rules_csv['Disposition'].uniq.compact.map{|d| {key: d, value: d}}
    
    render json: {categories: categories, brands: brands, grades: grades, dispositions: dispositions, return_reasons: return_reasons}
  end
  
  def update_rules
    sub_locations = SubLocation.where(id: params[:sub_location_ids])
    raise CustomErrors.new "Invalid Sub Location IDs." unless sub_locations.present?
    
    sub_locations.update_all(category: params[:category], brand: params[:brand], grade: params[:grade], disposition: params[:disposition], return_reason: params[:return_reason])
    render json: {status: :ok}
  end
  
  def export_sublocations
    distribution_center = DistributionCenter.find_by_id(params[:location_id])
    raise CustomErrors.new "Invalid Location." if distribution_center.blank?
    
    file_csv = SubLocation.export_sublocations(distribution_center)
    
    send_data(file_csv, filename: "#{distribution_center.code}_sublocations.csv")
  end
  
  def import_sublocations
    SubLocation.import_sub_locations(params[:file])
    
    render json: { message: "Sub Locations imported successfully." }
  end
  
  def export_sublocation_sequence
    distribution_center = DistributionCenter.find_by_id(params[:location_id])
    raise CustomErrors.new "Invalid Location." if distribution_center.blank?
    
    file_csv = SubLocation.export_sublocation_sequence(distribution_center)
    
    send_data(file_csv, filename: "#{distribution_center.code}_sequence.csv")
  end
  
  def import_sublocation_sequence
    SubLocation.update_sequence(params[:file])
    
    render json: { message: "Sub Location sequence updated successfully." }
  end

  private
    def set_sub_location
      @sub_location = SubLocation.find_by(id: params[:id])
    end

    def sub_location_params
      params.require(:sub_location).permit(:name, :distribution_center_id, :code, :location_type, :sequence)
    end
    
    def get_sub_locations
      @sub_locations = SubLocation.includes(:distribution_center).order(updated_at: :desc)
      # @sub_locations = @distribution_center.sub_locations if @distribution_center.present?
      @sub_locations = @sub_locations.where("name ilike ? OR code ilike ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
      @sub_locations = @sub_locations.where(location_type: params[:location_type]) if params[:location_type].present?
      @sub_locations = @sub_locations.where(distribution_center_id: JSON.parse(params[:distribution_center_ids])) if (params[:distribution_center_ids].present? and JSON.parse(params[:distribution_center_ids]).present?)
    end
end
