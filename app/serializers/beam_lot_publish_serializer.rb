class BeamLotPublishSerializer < ActiveModel::Serializer

  attributes :organization, :service_request_id, :username, :lot_name, :lot_desc, :mrp, :start_date, :end_date, :order_amount, :order_number, :floor_price, :reserve_price, :buy_now_price, :increment_slab, :quantity, :inventories, :lot_image_urls, :master_lot_file_url

  def initialize(object, options = {})
    @account_setting = options.dig(:adapter_options, :account_setting)
    @current_user = options.dig(:adapter_options, :current_user)
    super
  end

  def inventories
  	inv = []
  	if object.liquidations.present?
	  	object.liquidations.each do |liquidation|
	  		if liquidation.inventory.present?
	  			inventory = liquidation.inventory
	  			inv << {tag_number: inventory.tag_number, category_l1: inventory.details["category_l1"], 
	  							category_l2: inventory.details["category_l2"], category_l3: inventory.details["category_l3"],
	  							price: inventory.item_price, special_price: inventory.item_price, title: inventory.item_description, serial_number: inventory.serial_number,
	  							brand: inventory.details["brand"], quantity: inventory.quantity, inventory_grade: inventory.grade, city: inventory&.distribution_center&.city&.original_code, remarks: liquidation.remarks, floor_price: liquidation.floor_price }
	  		end
	  	end
  	end
  	return inv
  end

  def organization
    if @account_setting.liquidation_lot_file_upload
      @current_user.distribution_centers&.first&.name
    else
      @current_user.organization_name
    end
  end

  def service_request_id
    @account_setting.service_request_id
  end

  def username
    if @account_setting.liquidation_lot_file_upload
      @current_user.username
    else
      @account_setting.username
    end
  end

  def master_lot_file_url
    object.details['master_lot_file_url'] rescue nil
  end

  def start_date
    object.start_date_with_localtime.strftime("%d/%b/%Y %I:%M %P").to_datetime.utc rescue object.start_date
  end

  def end_date
    object.end_date_with_localtime.strftime("%d/%b/%Y %I:%M %P").to_datetime.utc rescue object.end_date
  end
end
