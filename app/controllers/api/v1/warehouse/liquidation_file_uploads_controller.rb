class Api::V1::Warehouse::LiquidationFileUploadsController < ApplicationController
  before_action :set_admin_liquidation_file_upload, only: [:show, :update, :destroy]

  # GET /admin/liquidation_file_uploads
  def index
    
    set_pagination_params(params)
    @liquidation_file_uploads = LiquidationFileUpload.all.order('id desc').page(@current_page).per(@per_page)
    render json: @liquidation_file_uploads, meta: pagination_meta(@liquidation_file_uploads) 

    
  end

  # GET /admin/liquidation_file_uploads/1
  def show
    render json: @liquidation_file_upload
  end

  # POST /admin/liquidation_file_uploads
  def create
    @liquidation_file_upload = LiquidationFileUpload.new(liquidation_file:params[:file],user_id:current_user.id)

    if @liquidation_file_upload.save
      #render json: @liquidation_file_upload, status: :created, location: @liquidation_file_upload
    else
      #render json: @liquidation_file_upload.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/liquidation_file_uploads/1
  def update
    if @liquidation_file_upload.update(admin_liquidation_file_upload_params)
      render json: @liquidation_file_upload
    else
      render json: @liquidation_file_upload.errors, status: :unprocessable_entity
    end
  end

  # DELETE /admin/liquidation_file_uploads/1
  def destroy
    @liquidation_file_upload.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin_liquidation_file_upload
      @liquidation_file_upload = LiquidationFileUpload.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def admin_liquidation_file_upload_params
      params.fetch(:liquidation_file_upload, {})
    end
end
