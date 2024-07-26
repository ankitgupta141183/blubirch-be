class Admin::AttributeMastersController < ApplicationController
  before_action :set_attribute_master, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @attribute_masters = AttributeMaster.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @attribute_masters, meta: pagination_meta(@attribute_masters)   
  end

  def show
    render json: @attribute_master
  end

  def create
    @attribute_master = AttributeMaster.new(attribute_master_params)

    if @attribute_master.save
      render json: @attribute_master, status: :created
    else
      render json: @attribute_master.errors, status: :unprocessable_entity
    end
  end

  def import
    @attribute_masters = AttributeMaster.import_attributes(params[:file])
    render json: @attribute_masters
  end

  def update
    if @attribute_master.update(attribute_master_params)
      render json: @attribute_master
    else
      render json: @attribute_master.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @attribute_master.destroy
  end

  private
 
  def set_attribute_master
    @attribute_master = AttributeMaster.find(params[:id])
  end

  def attribute_master_params
    params.require(:attribute_master).permit(:attr_type, :reason, :attr_label, :field_type, :options, :deleted_at)
  end

  def filtering_params
    params.slice(:attr_type, :reason, :attr_label, :field_type, :options)
  end

end
