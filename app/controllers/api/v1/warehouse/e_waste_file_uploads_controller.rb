class Api::V1::Warehouse::EWasteFileUploadsController < ApplicationController
  before_action :set_e_waste_file_upload, only: [:show, :update, :destroy]

  # GET /e_waste_file_uploads
  def index
    set_pagination_params(params)
    @e_waste_file_uploads = EWasteFileUpload.all.order('id desc').page(@current_page).per(@per_page)
    render json: @e_waste_file_uploads, meta: pagination_meta(@e_waste_file_uploads)     
  end

  # GET /e_waste_file_uploads/1
  def show
    render json: @e_waste_file_upload
  end

  # POST /e_waste_file_uploads
  def create
    @e_waste_file_upload = EWasteFileUpload.new(e_waste_file:params[:file],user_id:current_user.id)
    if @e_waste_file_upload.save
      #render json: @e_waste_file_upload, status: :created, location: @e_waste_file_upload
    else
      #render json: @e_waste_file_upload.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /e_waste_file_uploads/1
  def update
    if @e_waste_file_upload.update(e_waste_file_upload_params)
      render json: @e_waste_file_upload
    else
      render json: @e_waste_file_upload.errors, status: :unprocessable_entity
    end
  end

  # DELETE /e_waste_file_uploads/1
  def destroy
    @e_waste_file_upload.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_e_waste_file_upload
      @e_waste_file_upload = EWasteFileUpload.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def e_waste_file_upload_params
      params.fetch(:e_waste_file_upload, {})
    end
end