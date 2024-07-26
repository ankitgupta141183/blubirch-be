class Admin::RepairPartsController < ApplicationController

  before_action :repair_parts, only: [:show, :edit, :update, :destroy]

  def index
    set_pagination_params(params)
    # @repair_partss = RepairPart.filter(filtering_params).page(@current_page).per(@per_page)
    @repair_parts = RepairPart.all.page(@current_page).per(@per_page)
    render json: @repair_parts, meta: pagination_meta(@repair_parts)
  end

  def show
   render json: @repair_parts
  end

  def create
    @repair_parts = RepairPart.new(repair_parts_params)
    if @repair_parts.save
      render json: @repair_parts, status: :created
    else
      render json: @repair_parts.errors, status: :unprocessable_entity
    end
  end

  def edit
    render json: @repair_parts
  end

  def update
    if @repair_parts.update(repair_parts_params)
      render json: @repair_parts
    else
      render json: @repair_parts.errors, status: :unprocessable_entity
    end
  end

  def import
    @repair_parts = RepairPart.import(params[:file])
    render json: @repair_parts, status: :created
  end

  def destroy
    @repair_parts.destroy
  end

  private

  def repair_parts
   @repair_parts = RepairPart.find(params[:id])
  end

  def repair_parts_params
   params.require(:repair_parts).permit(:name, :part_number, :price, :hsn_code, :is_active)
  end

  # def filtering_params
 #    params.slice(:name, :code, :ancestry)
 #  end

end
