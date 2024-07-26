class Admin::ReturnInventoryInformationsController < ApplicationController

	def create
		master_file_upload = MasterFileUpload.new(master_file_upload_params)
    if master_file_upload.save
      render json: master_file_upload, status: :created
    else
      render json: master_file_upload.errors, status: :unprocessable_entity
    end      
	end

	private

  def master_file_upload_params
    params.permit(:master_file_type, :master_file, :user_id)
  end

end
