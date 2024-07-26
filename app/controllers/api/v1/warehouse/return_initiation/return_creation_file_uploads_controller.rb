class Api::V1::Warehouse::ReturnInitiation::ReturnCreationFileUploadsController < ApplicationController

  def index
    set_pagination_params(params)
    return_file_uploads = ReturnFileUpload.all.reorder(updated_at: :desc).page(@current_page).per(@per_page)
    render json: return_file_uploads, meta: pagination_meta(return_file_uploads)
  end

  def create
		return_file_upload = ReturnFileUpload.new(return_file: params[:file],user_id: current_user.id, return_type: params[:return_type])

    if return_file_upload.save
      render json: return_file_upload, status: :created
    else
      render json: return_file_upload.errors, status: :unprocessable_entity
    end
	end

  def show
    return_file_upload = ReturnFileUpload.find(params[:id])
    render json: return_file_upload
  end

end
