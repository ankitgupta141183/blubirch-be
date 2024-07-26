class Api::V2::Warehouse::InventoryFileUploadsController < ApplicationController
  before_action -> { set_pagination_params(params) }, only: :index
  before_action :get_distribution_centers, only: :download_competitive_liquidations

  def index
    inventory_file_upload = InventoryFileUpload.all
    inventory_file_upload = inventory_file_upload.where(inventory_file: params[:search_text].split(',').compact) if params[:search_text].present?
    inventory_file_upload = inventory_file_upload.order('id desc').page(@current_page).per(@per_page)
    render_collection(inventory_file_upload, Api::V2::Warehouse::InventoryFileUploadsSerializer)
  end

  def create
    inventory_file_upload = InventoryFileUpload.new(inventory_file: params[:file], user_id: @current_user.id, inward_type: params['inward_type'], status: "Uploading")

    if inventory_file_upload.save
      InventoryFileUploadWorker.perform_in(1.minutes, inventory_file_upload.id)
      render_success_message("Successfully uploaded.", :ok)
    else
      render_error('Something went wrong.', :unprocessable_entity)
    end
  end

  def download_competitive_liquidations
    liquidation_ids = Liquidation.where(id: params[:liquidation][:ids]).pluck(:id)
    if @current_user.email.present?
      LiquidationDataMailerWorker.perform_async(@current_user.id, @distribution_center_ids, liquidation_ids)
      render_success_message("Download link will be sent to you on #{@current_user.email}.", :ok)
    else
      render_error("User #{@current_user.username} email is not present.", :unprocessable_entity)
    end
  end
end
