class Api::V1::Warehouse::MarkdownsController < ApplicationController

	def index
    get_markdown
    if current_user.roles.last.name == "Default User"
      @items = check_user_accessibility(@markdowns, @distribution_center_detail)
      @markdowns = @markdowns.where(id: @items.pluck(:id)).order('updated_at desc')
    end
    @markdowns = @markdowns.page(@current_page).per(@per_page)
    render json: @markdowns, meta: pagination_meta(@markdowns)
  end

  def search_item
    set_pagination_params(params)
    get_distribution_centers
    search_param = params['search'].split(',').collect(&:strip).flatten
    @markdowns = Markdown.where(status: params['status'], is_active: true, distribution_center_id: @distribution_center_ids).where("lower(#{params['search_in']}) IN (?) ", search_param.map(&:downcase)).page(@current_page).per(@per_page)
    @markdowns = @markdowns.where("lower(details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    @markdowns = @markdowns.page(@current_page).per(@per_page)
    render json: @markdowns, meta: pagination_meta(@markdowns)
  end

	def get_distribution_center
		@dc = DistributionCenter.where("site_category in (?)", ["A", "D", "B", "R"])
		render json: @dc
	end

	def get_vendor_markdown
    @vendor_master = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': ["Pending Transfer Out", "Internal Vendor"]).where.not(vendor_code: current_user.distribution_centers.pluck(:code)).distinct
    render json: @vendor_master
	end

	def markdown_update
		@markdown = Markdown.where(id: params["id"]).first
		markdown_dispatch_status = LookupValue.find_by(code: Rails.application.credentials.markdown_status_pending_markdown_dispatch)
		if @markdown.present?
			file_type = LookupValue.find_by_code(Rails.application.credentials.markdown_file_type_markdown_destination)
			if params["files"].present?
				params["files"].each do |file|
          @markdown.markdown_attachments.create(attachment_file: file, attachment_file_type: file_type.original_code) rescue nil
        end
      end
      Markdown.where(id: params["id"]).update_all(status_id: markdown_dispatch_status.id, status: markdown_dispatch_status.original_code, destination_remark: params["destination_remark"], destination_code: params["destination_code"])
			markdown_history = @markdown.markdown_histories.new(status_id: markdown_dispatch_status.id)
			markdown_history.details = {}
      key = "#{markdown_dispatch_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
      markdown_history.details[key] = Time.now
      markdown_history.details["status_changed_by_user_id"] = current_user.id
      markdown_history.details["status_changed_by_user_name"] = current_user.full_name
      markdown_history.save
      get_markdown
      @markdowns = @markdowns.page(@current_page).per(@per_page)
      render json: @markdowns
		else
			render json: "Markdown not updated", status: :unprocessable_entity
		end
	end

	def markdown_dispatch_complete
  	if params.present?
			param = []
			param = JSON.parse(params["markdowns"])
			markdown_order = MarkdownOrder.new(vendor_code: params[:vendor_code], order_number: "OR-PTO-#{SecureRandom.hex(6)}")
			markdown_order.save
      warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick)
      warehouse_order = markdown_order.warehouse_orders.new(distribution_center_id: param.first["distribution_center_id"], status_id:  warehouse_order_status.id, total_quantity: param.count, vendor_code: params[:vendor_code])
      warehouse_order.client_id = param.first.client_id rescue nil
      warehouse_order.save
      
      param.each do |mark|
				@markdown = Markdown.where(id: mark["id"]).first
				if @markdown.present?
					markdown_dispatch_complete_status = LookupValue.find_by(code: Rails.application.credentials.markdown_status_markdown_dispatch_complete)
		      Markdown.where(id: mark["id"]).update_all(status_id: markdown_dispatch_complete_status.id, status: markdown_dispatch_complete_status.original_code, markdown_order_id: markdown_order["id"], is_active: false)
		      #Warehouse Order Item Creation
		      client_category = ClientSkuMaster.find_by_code(mark["sku_code"]).client_category rescue nil
          warehouse_order_item = warehouse_order.warehouse_order_items.new(inventory_id: mark["inventory_id"], sku_master_code: mark["sku_code"], item_description: mark["item_description"], tag_number: mark["tag_number"], quantity: 1, status_id: warehouse_order_status.id, status: warehouse_order_status.original_code, serial_number: @markdown.inventory.serial_number, toat_number: mark["toat_number"])
          warehouse_order_item.client_category_id = client_category.id rescue nil
          warehouse_order_item.client_category_name = client_category.name rescue nil
          warehouse_order_item.aisle_location = mark["aisle_location"] rescue nil
          warehouse_order_item.details = @markdown.inventory.details
          warehouse_order_item.save
          #Markdown History Creation
					markdown_history = @markdown.markdown_histories.new(status_id: @markdown.status_id)
					markdown_history.details = {}
		      key = "#{markdown_dispatch_complete_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
		      markdown_history.details[key] = Time.now
          markdown_history.details["status_changed_by_user_id"] = current_user.id
          markdown_history.details["status_changed_by_user_name"] = current_user.full_name
		      markdown_history.save
				end
			end
			render json: {order_number: markdown_order.order_number}
		else
			render json: "Markdown dispatch not completed", status: :unprocessable_entity
		end
	end

	private

  def get_markdown
  	set_pagination_params(params)
    get_distribution_centers
    @markdowns = Markdown.dc_filter(@distribution_center_ids).where(is_active: true, status: params['status']).order('updated_at desc')
    @markdowns = @markdowns.where("lower(details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
  end

  def check_user_accessibility(items, detail)
    result = []
    items.each do |item|
      origin_location_id = DistributionCenter.where(code: item.details["destination_code"]).pluck(:id)
      if ( (detail["grades"].include?("All") ? true : detail["grades"].include?(item.grade) ) && ( detail["brands"].include?("All") ? true : detail["brands"].include?(item.inventory.details["brand"]) ) && ( detail["warehouse"].include?(0) ? true : detail["warehouse"].include?(item.distribution_center_id) ) && ( detail["origin_fields"].include?(0) ? true : detail["origin_fields"].include?(origin_location_id)) )
        result << item 
      end
    end
    return result
  end

  def get_distribution_centers
    @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @distribution_center_detail = ""
    if ["Default User", "Site Admin"].include?(current_user.roles.last.name)
      id = []
      if @distribution_center.present?
        ids = [@distribution_center.id]
      else
        ids = current_user.distribution_centers.pluck(:id)
      end
      current_user.distribution_center_users.where(distribution_center_id: ids).each do |distribution_center_user|
        @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "Pending Transfer Out" || d["disposition"] == "All"}.last
        if @distribution_center_detail.present?
          @distribution_center_ids = @distribution_center_detail["warehouse"].include?(0) ? DistributionCenter.all.pluck(:id) : @distribution_center_detail["warehouse"]
          return
        end
      end
    else
      @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : DistributionCenter.all.pluck(:id)
    end
  end

end