class Api::V1::Warehouse::InventoryFileUploadsController < ApplicationController

  def index
    set_pagination_params(params)
    @inventory_file_upload = InventoryFileUpload.all.order('id desc').page(@current_page).per(@per_page)
    render json: @inventory_file_upload, meta: pagination_meta(@inventory_file_upload)
  end

  def create
    @inventory_file_upload = InventoryFileUpload.new(inventory_file: params[:file], user_id: current_user.id, inward_type: params[:inward_type], status: "Import Started")

    if @inventory_file_upload.save
      InventoryFileUploadWorker.perform_in(1.minutes, @inventory_file_upload.id)
      render json: @liquidation_file_upload, location: @liquidation_file_upload
    else
      render json: @liquidation_file_upload.errors, status: :unprocessable_entity
    end
  end

  def update
    @liquidation_order = LiquidationOrder.find(params[:id])
    if @liquidation_order.update(lot_params)
      if params[:vendor_lists].present?
        @liquidation_order.details ||= {}
        @liquidation_order.details['vendor_lists'] = params[:vendor_lists]
        @liquidation_order.save
      end
      unless params[:lot][:images].blank?
        params[:lot][:images].each do |file|
          l=@liquidation_order.lot_attachments.new(attachment_file: file)
          l.save!
        end
      end
      unless JSON.parse(params[:lot][:removed_urls]).blank?
        lot_images = (@liquidation_order.lot_image_urls - JSON.parse(params[:lot][:removed_urls])).flatten.compact.uniq
        @liquidation_order.update(lot_image_urls: lot_images)
        @liquidation_order.lot_attachments.each do |attachment|
          attachment.destroy if JSON.parse(params[:lot][:removed_urls]).include?(attachment.attachment_file_url)
        end
      end
      unless JSON.parse(params[:lot][:image_urls]).blank?
        lot_images = (@liquidation_order.lot_image_urls += JSON.parse(params[:lot][:image_urls])).flatten.compact.uniq
        @liquidation_order.update(lot_image_urls: lot_images)
      end
      update_image_urls(@liquidation_order.id)
      render json: @liquidation_order
    else
      render json: @liquidation_order.errors.full_messages, status: :unprocessable_entity
    end
  end

  def get_edit_lot_images
    lot = LiquidationOrder.find(params[:id])
    lot_images = lot.lot_image_urls.uniq
    all_images = []
    lot.liquidations.each do |l|
      all_images << l.inventory.inventory_grading_details.last.details["final_grading_result"]["Item Condition"][0]["annotations"].last["src"] rescue ''
    end
    unselected_images = (all_images - lot_images).flatten.compact.uniq
    render json: {lot_images: lot_images, inv_images: unselected_images}
  end

  private
  def lot_params
    params.require(:liquidation_order).permit(:floor_price, :reserve_price, :buy_now_price, :increment_slab, :end_date, :start_date, :order_amount, lot_image_urls: [])
  end

  def update_image_urls(liquidation_order_id)
    @liquidation_order = LiquidationOrder.find(liquidation_order_id)
    @liquidation_order.lot_attachments.collect(&:attachment_file).collect(&:url)
    lot_images = (@liquidation_order.lot_image_urls += @liquidation_order.lot_attachments.map(&:attachment_file_url)).flatten.compact.uniq
    @liquidation_order.update(lot_image_urls: lot_images)
  end

end