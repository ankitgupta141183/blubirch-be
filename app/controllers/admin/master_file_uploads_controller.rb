class Admin::MasterFileUploadsController < ApplicationController
  before_action :set_master_file_upload, only: [:show, :update, :destroy, :retry_upload]

  def index
    set_pagination_params(params)
    if params["file_type"].present?
      @master_file_uploads = MasterFileUpload.where(master_file_type: params["file_type"]).order('id desc').page(@current_page).per(@per_page)
    else
      @master_file_uploads = MasterFileUpload.all.order('id desc').page(@current_page).per(@per_page)
    end
    render json: @master_file_uploads, meta: pagination_meta(@master_file_uploads)
  end

  def show
    render json: @master_file_upload
  end

  def create
    @master_file_upload = MasterFileUpload.new(master_file_upload_params)
    if @master_file_upload.save
      render json: @master_file_upload, status: :created
    else
      render json: @master_file_upload.errors, status: :unprocessable_entity
    end
  end

  def fetch_grading_type
    @grading_types = LookupKey.find_by(name:"GRADING_TYPE").lookup_values.collect(&:original_code)
    render json: { grading_types: @grading_types }
  end

  def fetch_distribution_centers
    @distribution_centers = DistributionCenter.all
    render json: { distribution_centers: @distribution_centers }
  end

  def update
    if @master_file_upload.update(master_file_upload_params)
      render json: @master_file_upload
    else
      render json: @master_file_upload.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @master_file_upload.destroy
  end

  def retry_upload
    @master_file_upload.update_columns(status: "Retrying", remarks: nil)
    @master_file_upload.upload_file
    render json: { message: "Retrying" }, status: 200
  end

  private

  def set_master_file_upload
    @master_file_upload = MasterFileUpload.find(params[:id])
    return render json: { message: "Record Not Found" }, status: 404 unless @master_file_upload
  end

  def master_file_upload_params
    params.permit(:master_file_type, :master_file, :status, :remarks, :user_id, :client_id, :grading_type, :distribution_center_id, :vendor_master_id)
  end
end
