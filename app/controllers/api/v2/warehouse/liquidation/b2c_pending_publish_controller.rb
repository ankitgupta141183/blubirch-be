class Api::V2::Warehouse::Liquidation::B2cPendingPublishController < Api::V2::Warehouse::LiquidationsController
  STATUS = "Pending B2C Publish"

  #before_action :validate_lot_params, only: :publish
  before_action :validate_b2c_publish, only: :publish
  before_action :set_liquidations, only: :move_to_b2b

  def get_platform_list
    data = []
    account_setting = AccountSetting.first
    if account_setting.present? && account_setting.ext_b2c_platforms.present?
      account_setting.ext_b2c_platforms.each do |key, value|
        data << { id: key, name: value }
      end
    end
    render json: { ext_platform_names: data }
  end

  def publish
    liquidations = Liquidation.where(id: ecom_params["liquidation_ids"].to_s.split(','))
    begin
      ActiveRecord::Base.transaction do 
        liquidations.each do |liquidation|
          liquidation.update!(b2c_publish_status: Liquidation.b2c_publish_statuses[:publish_initiated])
          liquidation.reload
    
          #& Initialize EcomLiquidation
          ecom_liquidation = liquidation.ecom_liquidations.new({
                     tag_number: liquidation.tag_number,
                  inventory_sku: liquidation.sku_code,
          inventory_description: liquidation.item_description,
                   inventory_id: liquidation.inventory_id,
                        user_id: current_user.id,
                          grade: liquidation.grade,
                          brand: liquidation.brand,
                 liquidation_id: liquidation.id,
                       platform: ecom_params['platform'],
                    category_l1: liquidation.details['category_l1'],
                    category_l2: liquidation.details['category_l2'],
                    category_l3: liquidation.details['category_l3'],
                       quantity: 1, #! No functionality to add quantity
                       discount: ecom_params['discount'].to_i,
                         amount: ecom_params['publish_price'].to_i,
                     start_time: ecom_params['start_date'],
                       end_time: ecom_params['end_date'],
            #external_request_id: , #! Will be stored once item is created in other platform side
            #external_product_id: , #! Will be stored once we receive callback from bmaxx
            #            detials: , #! Will be stored once item is created in other platform side
                         status: 'Pending B2C Publish',
                         vendor_code: liquidation.vendor_code
          })
          ecom_liquidation.ecom_images =  params['images'] if params['images'].present?
          ecom_liquidation.ecom_videos =  ecom_params['videos'] if ecom_params['videos'].present?
          raise 'vendor code cannot be blank for liquidation' if liquidation.vendor_code.blank?
          ecom_liquidation.save!
        end
      end
      render_success_message("Sent for publish successfully", :ok)
    rescue => e
      raise e.message and return
    end
  end

  def resync_publish
    ecom_liquidations = EcomLiquidation.where(id: params['ids'].split_with_gsub)
    ecom_liquidations.each do |ecom_liquidation|
      if (ecom_liquidation.publish_status_failed? || ecom_liquidation.publish_status_publish_initiated?) && time_difference(ecom_liquidation.updated_at, 10)
        ecom_liquidation.create_record_on_platform
      else
        raise "Cannot Sync the record of an article id #{ecom_liquidation.inventory_sku}" and return
      end
    end
    render_success_message("Resync Done Successfully", :ok)
  end

  def move_to_b2b
    liquidation_status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_allocate_b2b)
    begin
      update_liquidations_status(status: liquidation_status.original_code, status_id: liquidation_status.id)
    rescue => e
      render_error(e.message, 500)
    end
  end

  private

    def lot_params
      params.require(:lot).permit(:platform, :publish_price, :discount, :images, :videos, :start_date, :end_date, :liquidation_id)
    end

    def ecom_params
      params.require(:ecom_liquidation).permit(:platform, :publish_price, :discount, :images, :videos, :start_date, :end_date, :liquidation_ids)
    end

    def lot_params_b2c
      lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_b2c)
      lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_in_progress_b2c)
      {
        lot: {
          lot_type: lot_type.original_code,
          lot_type_id: lot_type.id,
          status: lot_status.original_code,
          status_id: lot_status.id,
          discount: lot_params[:discount]&.to_f,
          publish_price: lot_params[:publish_price]&.to_f,
          end_date: lot_params[:end_date],
          start_date: lot_params[:start_date],
          platform: lot_params[:platform],
        },
        images: params[:images],
        removed_urls: params[:removed_urls],
        image_urls: params[:image_urls],
        liquidation_ids: Array(lot_params[:liquidation_id]),
      }
    end

    def validate_b2c_publish
      required_params = {
        discount: "Missing required param 'discount'.",
        publish_price: "Missing required param 'publish_price'.",
        start_date: "Missing required param 'start_date'.",
        end_date: "Missing required param 'end_date'.",
        platform: "Missing required param 'platform'.",
        liquidation_ids: "Missing required param 'liquidation_ids'."
      }
      required_params.each do |param, error_message|
        render_error(error_message, 422) and return if ecom_params[param].blank?
      end
      render_error("invalid platform", 422) and return if EcomLiquidation.platforms.keys.exclude?(ecom_params['platform'].to_s)
      liquidations = Liquidation.where(id: ecom_params['liquidation_ids'])
      liquidations.each do |liq|
        render_error("Vendor_code is blank for #{liq.item_description}", 422) and return if liq.vendor_code.blank?
        render_error("Client Category is not present for  #{liq.item_description}", 422) and return if liq.client_category.blank?
        render_error("Seller Category is not present for  #{liq.item_description}", 422) and return if liq.client_category.seller_category.blank?
        render_error("Bmaxx Category details mapping is not present for  #{liq.item_description}", 422) and return if (liq.client_category.seller_category.details['bmaxx_child'].blank? || liq.client_category.seller_category.details['bmaxx_parent'].blank?)
      end
    end
end
