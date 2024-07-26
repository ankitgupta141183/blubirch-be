class Admin::DistributionCentersController < ApplicationController
  skip_before_action :authenticate_user!, :check_permission, only: :sync_scb_org_data
  
  before_action :set_distribution_center, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    if params['select'].present? || params['list'].present?
      @distribution_centers = DistributionCenter.all
      render json: @distribution_centers
    else
      @distribution_centers = DistributionCenter.filter(filtering_params).page(@current_page).per(@per_page)
      render json: @distribution_centers, meta: pagination_meta(@distribution_centers)
    end
  end

  def show
    render json: @distribution_center
  end

  def create
    @distribution_center = DistributionCenter.new(distribution_center_params)
  
    if @distribution_center.save
      render json: @distribution_center, status: :created
    else
      render json: @distribution_center.errors, status: :unprocessable_entity
    end
  end

  def distribution_center_uploads
    file = params[:file]
    distribution_center_type = params[:distribution_center_type]
    distribution_centers = DistributionCenter.create_centers(file, distribution_center_type)

    if distribution_centers == true
      render json: {message: "Successfully created"}, status: :created
    else
      render json: distribution_centers['errors'], status: :unprocessable_entity
    end
  end

  def update
     if @distribution_center.update(distribution_center_params)
       render json: @distribution_center
     else
       render json: @distribution_center.errors, status: :unprocessable_entity
     end
  end

  def destroy
    @distribution_center.destroy
  end

  def search
    set_pagination_params(params)
    if params[:search_params]
      parameter = params[:search_params].downcase
      @search_results = DistributionCenter.all.where("lower(name) LIKE :search_params", search_params: "%#{parameter}%").page(@current_page).per(@per_page)
      render json: @search_results, meta: pagination_meta(@search_results)
    else
      render json: @search_results.errors, status: :unprocessable_entity
    end
  end

  def sync_scb_org_data
    begin
      ActiveRecord::Base.transaction do
        distribution_center = DistributionCenter.find_or_initialize_by(code: params.dig(:organization, :id))

        city_id    = LookupValue.find_by(original_code: params.dig(:organization, :city_name)).id    rescue nil
        state_id   = LookupValue.find_by(original_code: params.dig(:organization, :state_name)).id   rescue nil
        country_id = LookupValue.find_by(original_code: params.dig(:organization, :country_name)).id rescue nil

        distribution_center.update!(
          name: params.dig(:organization, :name),
          city_id: city_id,
          state_id: state_id,
          country_id: country_id,
          site_category: distribution_center.site_category || 'R'
        )

        if params[:user].present?
          user = User.find_or_initialize_by(username: params.dig(:user, :username))

          if params[:user_password].present?
            user.password = params[:user_password]
          elsif user.new_record?
            if params[:temp_password].present?
              user.password = params[:temp_password]
            else
              user.password = SecureRandom.hex(8)
            end
          end

          user.update!(
            email: params.dig(:user, :email),
            first_name: params.dig(:user, :first_name),
            last_name: params.dig(:user, :last_name),
            contact_no: params.dig(:user, :contact_number),
            onboarded_by: Role.find_by(code: 'superadmin')&.users&.first&.id || User.first.id
          )

          role_id = Role.find_by(name: "Central Admin").id
          user.user_roles.find_or_create_by(role_id: role_id)
          distribution_center.distribution_center_users.find_or_create_by(user_id: user.id)
          user.user_account_setting.update({
            bidding_method: params.dig(:user, :bidding_method),
            organization_name: distribution_center.name
          })
        end

        DashboardMappingWorker.perform_in(5.seconds)

        render_success_message("Successfully sync data", :ok)
      end
    rescue => e
      render_error(e.message, 500)
    end
  end

  private
  
    def set_distribution_center
      @distribution_center = DistributionCenter.find(params[:id])
    end

    def distribution_center_params
      params.require(:distribution_center).permit(:name, :address_line1, :address_line2, :address_line3, :address_line4, :city_id, :state_id, :country_id, :parent_id, :distribution_center_type_id, :code, details: {}, client_ids: [])
    end

    def filtering_params
      params.slice(:name, :parent_name,:address_line1, :address_line2, :city, :state)
    end
    
end
