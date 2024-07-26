class Admin::CostValuesController < ApplicationController
  before_action :set_cost_value, only: [:show, :update, :destroy]

  # GET /cost_values
  def index
    @cost_values = CostValue.all

    render json: @cost_values
  end

  # GET /cost_values/1
  # def show
  #   render json: @cost_value
  # end

  # POST /cost_values
  # def create
  #   @cost_value = CostValue.new(cost_value_params)

  #   if @cost_value.save
  #     render json: @cost_value, status: :created, location: @cost_value
  #   else
  #     render json: @cost_value.errors, status: :unprocessable_entity
  #   end
  # end

  # PATCH/PUT /cost_values/1
  # def update
  #   if @cost_value.update(cost_value_params)
  #     render json: @cost_value
  #   else
  #     render json: @cost_value.errors, status: :unprocessable_entity
  #   end
  # end

  # DELETE /cost_values/1
  # def destroy
  #   @cost_value.destroy
  # end

  def import 
    CostValue.import(params[:file])
    redirect_to  admin_cost_values_path, notice: "Cost Values Imported"
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_cost_value
      @cost_value = CostValue.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def cost_value_params
      params.require(:cost_value).permit(:category_id, :cost_attribute_id, :brand, :model, :value)
    end
end
