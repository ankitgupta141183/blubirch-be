class Api::V1::Pos::CoupanCodesController < ApplicationController
  before_action :set_coupan_code, only: [:show, :update, :destroy]

  # GET /coupan_codes
  def index
    @coupan_codes = CoupanCode.all

    render json: @coupan_codes
  end

  # GET /coupan_codes/1
  def show
    render json: @coupan_code
  end

  # POST /coupan_codes
  def create
    @coupan_code = CoupanCode.new(coupan_code_params)

    if @coupan_code.save
      render json: @coupan_code, status: :created, location: @coupan_code
    else
      render json: @coupan_code.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /coupan_codes/1
  def update
    if @coupan_code.update(coupan_code_params)
      render json: @coupan_code
    else
      render json: @coupan_code.errors, status: :unprocessable_entity
    end
  end

  # DELETE /coupan_codes/1
  def destroy
    @coupan_code.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_coupan_code
      @coupan_code = CoupanCode.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def coupan_code_params
      params.require(:coupan_code).permit(:coupan_code, :discount)
    end
end
