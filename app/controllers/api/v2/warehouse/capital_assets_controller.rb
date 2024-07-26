class Api::V2::Warehouse::CapitalAssetsController < ApplicationController
  STATUS = "Assets"

  before_action -> { set_pagination_params(params) }, only: :index
  before_action :filter_capital_asset_items, :search_capital_asset_items, only: [:index]
  before_action :set_capital_assets, only: [:get_distribution_users, :assigned_user, :unassigned_user, :update_disposition, :set_dispositions]
  before_action :set_distribution_center, only: [:get_distribution_users]
  before_action :check_for_assigned_item, only: [:set_dispositions]

  def index
    @capital_assets = @capital_assets.order('updated_at desc').page(@current_page).per(@per_page)
    render_collection(@capital_assets, Api::V2::Warehouse::CapitalAssetSerializer)
  end

  def assigned_user
    user = User.find_by(username: params[:username])
    if user.present?
      @capital_assets.update_all(assigned_to: params[:full_name], assigned_user_id: user.id, assigned_username: user.username, assignment_status: 'assigned')
      render_success_message("Successfully assigned items to #{params[:full_name]}!", :ok)
    else
      render_error("User is not valid!!!", 422)
    end
  end

  def unassigned_user
    @capital_assets.update_all(assigned_to: nil, assigned_user_id: nil, assigned_username: nil, assignment_status: 'unassigned')
    render_success_message("Successfully unassigned!", :ok)
  end

  def get_distribution_users
    users = @distribution_center.users
    render json: users.as_json(only: [:username, :id], methods: [:full_name])
  end

  def get_dispositions
    lookup_key = LookupKey.find_by(code: 'FORWARD_DISPOSITION')
    dispositions = lookup_key.lookup_values.where(original_code: ['Rental', 'Saleable', 'Demo', 'Replacement']).pluck(:original_code).map{|code| {id: code, code: code} }
    render json: { dispositions: dispositions }
  end

  def set_dispositions
    lookup_key = LookupKey.find_by(code: 'FORWARD_DISPOSITION')

    if @capital_assets.blank?
      render json: "Please Provide Valid Capital Asset Ids", status: :unprocessable_entity 
    else

      assigned_disposition = params[:disposition]
      @capital_assets.each do |capital_asset|
        ActiveRecord::Base.transaction do

          disposition = lookup_key.lookup_values.find_by_original_code(assigned_disposition)
          raise CustomErrors.new "Assigned disposition is blank for capital asset" if disposition.blank?

          capital_asset.update(
            assigned_disposition: assigned_disposition,
            assigned_user_id: current_user.id,
            is_active: false
          )

          inventory = capital_asset.inventory
          inventory.disposition = disposition.original_code
          inventory.save

          DispositionRule.create_fwd_bucket_record(disposition.original_code, inventory, 'Capital Asset', current_user.id)
        end
      end
      
      render json:{ message: "#{@capital_assets.count} item(s) moved to #{assigned_disposition} successfully" }
    end
  end

  private

  def search_capital_asset_items
    @capital_assets = @capital_assets.search_by_text(params[:search_text]) if params[:search_text].present?
  end

  def filter_capital_asset_items
    @capital_assets = CapitalAsset
    @capital_assets = @capital_assets.filter(params[:filter]) if params[:filter].present?
    @capital_assets = @capital_assets.where(is_active: true, status: self.class::STATUS)
  end

  def set_capital_assets
    render_error("Missing required param 'ids'.", 422) unless params[:ids].present?
    @capital_assets = CapitalAsset.where(id: params[:ids])
  end

  def set_distribution_center
    distribution_center_ids = @capital_assets.pluck(:distribution_center_id).uniq
    render_error("Please select only one distribution center items.", 422) if distribution_center_ids.count > 1
    @distribution_center = DistributionCenter.where(id: distribution_center_ids).first
  end

  def check_for_assigned_item
    assignment_statuses = @capital_assets.pluck(:assignment_status).uniq
    render_error('Unable to change assigned item disposition!', :unprocessable_entity) and return if assignment_statuses.include?('assigned')
  end
end
