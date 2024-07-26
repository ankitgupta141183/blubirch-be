class Api::V1::Warehouse::UsersController < ApplicationController

  def index
    set_pagination_params(params)
    if params[:search].present?
      @users = User.includes(:roles).with_deleted.where(email: params[:search]).order('created_at desc').page(@current_page).per(@per_page)
    else
      @users = User.includes(:roles).with_deleted.order('created_at desc').page(@current_page).per(@per_page)
    end
    if @users.present?
      render json: @users, each_serializer: Api::V1::Warehouse::UserListSerilaizer, meta: pagination_meta(@users)
    else
      render json: {message: "Not Found", status: 302}
    end
  end

  def fetch_all_info
    roles = Role.last(5).map {|r| {name: r.name, id: r.id}}
    product_access = ["STN Upload", "SKU Master", "Store Master", "Vendor Master", "Alerts", "Reports", "Issue Resolution", "Item Information", "Document Search", "Lot File Upload", "WmsChart", "Edit Item", "Inbound Documents"]
    warehouses = DistributionCenter.where("site_category in (?)", ["D", "R", "B", "E"]).map {|r| {name: r.code, id: r.id}}
    locations = DistributionCenter.where("site_category not in (?)", ["D", "R", "B", "E"]).map {|r| {name: r.code, id: r.id}}
    dispositions = ["Inward", "Pick and Pack", "Dispatch", "Brand Call-Log", "Liquidation", "Redeploy", "Repair", "Replacement", "Insurance", "RTV", "Regrade", "Stowing", "E-Waste", "Pending Disposition", "Pending Transfer Out"] 
    brand_types = ["OL", "Non OL"]
    class_descriptions = ClientSkuMaster.pluck(:item_type).uniq
    brands = ClientSkuMaster.pluck(:brand).uniq
    grades = LookupKey.where(name: 'INVENTORY_GRADE').last.lookup_values.map {|r| {name: r.original_code, id: r.id}}
    users = User.all.map {|u| {username: u.username, employee_id: u.employee_id, contact_no: u.contact_no}}

    render json: {users: users, roles: roles, product_access: product_access, warehouses: warehouses, locations: locations,
     dispositions: dispositions, class_descriptions: class_descriptions, brands: brands, brand_types: brand_types, grades: grades}
  end

  def show
    @user = User.with_deleted.find(params[:id])
    if @user.present?
      render json: @user
    else
      render json: {message: "Not Found", status: 302}
    end
  end

  def create
    begin
      ActiveRecord::Base.transaction do
        details = params[:user]
        onboarded_by_id = User.where(employee_id: params[:user][:onboraded_by_code]).last.id rescue ''
        user = User.new(username: details["full_name"], first_name: details["first_name"], last_name: details["last_name"], email: details["email"], contact_no: details["contact_no"], employee_id: details["employee_code"], status: "Active", tasks: {"product_access": params['product_access']}, onboarded_by: onboarded_by_id )
        user.password = "123456"
        if user.save
          user.user_roles.create(role_id: details["role_id"])
          create_module_access(params, user)
        end
        render json: "success", status: 200
      end
    rescue
      render json: {message: "Server Error", status: 302}
    end
  end

  def update
    begin
      ActiveRecord::Base.transaction do
        details = params[:user]
        onboarded_by_id = User.where(employee_id: params[:user][:onboarded_by_code]).last.id rescue ''
        user = User.with_deleted.find(params[:id])
        if user.present?
          user.update_attributes(username: details["full_name"], first_name: details["first_name"], last_name: details["last_name"], email: details["email"], contact_no: details["contact_no"], employee_id: details["employee_code"], status: "Active", tasks: {"product_access": params['product_access']}, onboarded_by: onboarded_by_id )
          user.user_roles.update_all(role_id: details["role_id"])
          create_module_access(params, user)
          render json: "success", status: 200
        else
          render json: {message: "Not Found", status: 302}
        end
      end
    rescue
      render json: {message: "Server Error", status: 302}
    end
  end

  def restore_user
    @user = User.with_deleted.find_by_id(params[:id])
    if @user.present?
      @user.restore!
      render json: {message: "User restored successfully", status: 200}
    else
      render json: {message: "Not Found", status: 302}
    end
  end

  def destroy
    @user = User.with_deleted.find_by_id(params[:id])
    if @user.present?
      if params[:delete] == "true"
        @user.really_destroy!
      else
        @user.delete
      end
      render json: {message: "User deleted successfully", status: 200}
    else
      render json: {message: "Not Found", status: 302}
    end
  end

  private

  def create_module_access(params, user)
    user.distribution_center_users.destroy_all
    params["module_access"].each do |data|
      data = JSON.parse(data)
      if data["warehouse"] == [0]
        warehouses = DistributionCenter.where("site_category in (?)", ["D", "R", "B", "E"])
        warehouses.each do |distribution_center|
          dc_user = DistributionCenterUser.new(user_id: user.id, distribution_center_id: distribution_center.id)
          dc_user.details << data
          dc_user.save
        end
      else
        data["warehouse"].each do |warehouse_id|
          distribution_center = DistributionCenter.find(warehouse_id.to_i)
          dc_user = DistributionCenterUser.new(user_id: user.id, distribution_center_id: distribution_center.id)
          dc_user.details << data
          dc_user.save
        end
      end
    end
  end
end