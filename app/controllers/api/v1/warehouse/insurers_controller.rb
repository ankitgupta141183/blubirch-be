class Api::V1::Warehouse::InsurersController < ApplicationController
  before_action :set_insurer, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @insurers = Insurer.order(id: :desc)
    @insurers = @insurers.where("name ilike ?", "%#{params[:search]}%") if params[:search].present?
    @insurers = @insurers.page(@current_page).per(@per_page)
    data = @insurers.as_json(only: [:id, :name], methods: [:added_on])
    render json: { insurers: data, meta: pagination_meta(@insurers)}
  end
  
  def get_insurer_configs
    insurance_value_parameters = Insurer.insurance_value_parameters.except(:purchase_price).keys.map{|i| {id: i, name: i.upcase} }
    insurance_value_parameters.insert(0, {id: "purchase_price", name: "Purchase Price"})
    claim_raising_methods = Insurer.claim_raising_methods.except(:api).keys.map{|i| {id: i, name: i.titleize} }
    claim_raising_methods.insert(0, {id: "api", name: "API"})
    data_types = Insurer::DATA_TYPES.map{|i| {id: i, name: i.titleize} }

    render json: {insurance_value_parameters: insurance_value_parameters, claim_raising_methods: claim_raising_methods, data_types: data_types}
  end

  def create
    raise CustomErrors.new "Can not add more than 1 Insurer." if Insurer.count >= 1
    
    @insurer = Insurer.new(insurer_params)
    @insurer.insurance_claim_type = params[:insurer][:insurance_claim_type]
    @insurer.required_documents = params[:insurer][:required_documents]
    # raise CustomErrors.new "'Type of Insurance Claim' should not be blank." if @insurer.insurance_claim_type.blank?

    if @insurer.save
      render json: { message: "Insurer created successfully." }
    else
      render json: {error: @insurer.errors.full_messages}
    end
  end
  
  def show
    data = @insurer.as_json(except: [:created_at, :updated_at])
    data[:created_at] = format_ist_time(@insurer.created_at)
    data[:updated_at] = format_ist_time(@insurer.updated_at)
  
    render json: {insurer: data}
  end
  
  def update
    #@insurer.assign_attributes(insurer_params)
    #@insurer.insurance_claim_type = params[:insurer][:insurance_claim_type]
    #@insurer.required_documents = params[:insurer][:required_documents]
    @insurer.name = params[:insurer][:name]
    if @insurer.save
      render json: { message: "Insurer updated successfully." }
    else
      render json: {error: @insurer.errors.full_messages}
    end
  end
  
  def bulk_delete
    insurers = Insurer.where(id: params[:ids])
    raise CustomErrors.new "Invalid ID" if insurers.blank?
    
    insurances = Insurance.where(insurer_id: params[:ids])
    raise CustomErrors.new "You can not perform this action. This Insurer is mapped to items." if insurances.present?
    insurers.destroy_all
    
    render json: {status: :ok}
  end

  
  private
  
  def set_insurer
    @insurer = Insurer.find_by(id: params[:id])
  end
  
  def insurer_params
    params.require(:insurer).permit(:name, :timeline, :insurance_value_parameter, :insurance_cover, :excess, :claim_raising_method)
  end
  
end
