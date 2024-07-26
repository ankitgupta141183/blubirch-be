class Api::V2::Warehouse::ReturnInventoriesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :check_permission
  before_action -> { set_pagination_params(params) }, only: :inventories
  before_action :get_inventories, only: :inventories

  def inventories
    @inventories = Kaminari.paginate_array(@inventories).page(@current_page).per(@per_page)
    render_collection(@inventories, nil)
  end
  
  def show
    return_inventory = ReturnInventory.find(params[:id])
    render json: return_inventory
  end

  def create
    begin 
      ActiveRecord::Base.transaction do
        inventory = Inventory.find(params['id'])
        client_sku_master = ClientSkuMaster.where("code = ? and (description ->> 'category_l1') = ? and (description ->> 'category_l2') = ? and (description ->> 'category_l3') = ?", inventory.sku_code, inventory.details['category_l1'], inventory.details['category_l2'], inventory.details['category_l3']).last
        return_inventory = ReturnInventory.create!({
          inventory_id: inventory.id,
          tag_number: inventory.tag_number,
          sku_code: inventory.sku_code,
          serial_number: inventory.serial_number,
          headers_data: JSON.parse(params.to_json)
        })
        final_message, errors_messages = AiFakeService.call_request(client_sku_master, return_inventory)
        render json: { return_inventory_id: return_inventory.id, message: final_message, error_messages: errors_messages }
      end
    rescue => except
      render_error_with_backtrace(except.message, except.backtrace.to_s.truncate(1000), 422)
    end
  end

  def update_record
    begin
      return_inventory = ReturnInventory.find(params['File-id'])
      return_inventory.update!(response_data: {
        "final-prediction" => params["final-prediction"],
        "prediction-score" => params["prediction-score"]
      })
      render json: { message: "Date updated successfully" }
    rescue => except
      render_error_with_backtrace(except.message, except.backtrace.to_s.truncate(1000), 422)
    end
  end

  private 

  def get_inventories
    code_with_category_with_images_hash = {}  
    ClientSkuMaster.where.not("images = ?", '[]').select{|data| code_with_category_with_images_hash[data.code] = "#{data.description['category_l1']}::#{data.description['category_l2']}::#{data.description['category_l3']}::#{data.images.to_json}" }
    return render_error("No Data available", 404) if code_with_category_with_images_hash.blank?
    @inventories = []
    Inventory.where(sku_code: code_with_category_with_images_hash.keys).each do |inv|
      categories = code_with_category_with_images_hash[inv.sku_code]
      category_l1, category_l2, category_l3, images = categories.split('::')
      if category_l1 == inv.details['category_l1'] && category_l2 == inv.details['category_l2'] && category_l3 == inv.details['category_l3']
        inv_data = inv.attributes
        inv_data.merge!({ side_image_urls: JSON.parse(images) })
        @inventories << inv_data 
      end
    end
    return render_error("No Data available", 404) if @inventories.blank?
  end
  
  def filter_inventories
    if @inventories.present?
      @inventories = @inventories.select{|inv| inv.tag_number == params['tag_number'] } if params['tag_number'].present?
      @inventories = @inventories.select{|inv| inv.sku_code == params['sku_code'] } if params['sku_code'].present?
    end
  end

end
