class ApplicationController < ActionController::API

  # rescue_from JWT::VerificationError, with: :not_authorized
  # rescue_from CustomErrors, with: :render_unprocessable_entity
  rescue_from Exception, with: :handle_exception

  attr_reader :current_user
  include CheckPermission
  include ApiResponses
  attr_reader :distribution_center
  include ActionController::MimeResponds
  include Utils::Formatting
  
  around_action :use_logidze_responsible, only: %i[create update]

  # include RecordAccessible

  respond_to :json

  def pagination_meta(object)
    {
      current_page: (object.current_page rescue 1),
      next_page: (object.next_page rescue nil),
      prev_page: (object.prev_page rescue nil),
      total_pages: (object.total_pages rescue 0),
      total_count: (object.total_count rescue 0)
    }
  end

  def render_success_response(resources = {}, message = '', status = 200)
    render json: { success: true, message: message, data: resources}, status: status
  end

  def meta_message_attribute(message)
    {
      message: message
    }
  end

  def authenticate_user!
    begin
      payload = JWT.decode(request.headers['Authorization'].split(' ').try(:last), Rails.application.credentials.jwt_secret)
      if payload.try(:first)["jti"].present? 
        user = User.where("jti = ?", payload.try(:first)["jti"]).first
        if user.present?
          @current_user = user
          Current.user = user
          if request.headers['Filter'].present?
            @distribution_center = DistributionCenter.find(request.headers['Filter'].to_i)
          end
        else
          not_authorized
        end
      else
        not_authorized
      end
    rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError
      not_authorized
    end
  end

  def not_authorized
    render json: { error: 'Not authorized' }, status: :unauthorized
  end
  
  def render_unprocessable_entity(ex)
    render json: {error: ex.message}, status: 500
  end

  def use_logidze_responsible(&block)
    Logidze.with_responsible(current_user&.id, &block)
  end

  def set_pagination_params(params)
    @current_page = (params[:page].present? ? params[:page] : 1)
    @per_page = (params[:per_page].present? ? params[:per_page] : 10)
  end

  def is_standalone_application?
    account_setting = AccountSetting.last
    account_setting.present? && account_setting.liquidation_lot_file_upload?
  end

  def distribution_center
    current_user.try(:distribution_centers).try(:first)
  end

  def get_rule_engine_type
    base_url = request.base_url.split('//')[1]
    if ['ramp20-api.blubirch.com', 'https://croma.blubirch.com'].include?(base_url)
      3  #PRODUCTION RULE ENGINE https://ruleengine.blubirch.com/
    elsif ['qa-rims-api-k8s.blubirch.com'].include?(base_url)
      2 # UAT RULE ENGINE https://qa-ruleengine-k8s.blubirch.com/
    else
      1 #https://ruleengine-api.blubirch.com/
    end
  end

  def get_host
    if request.base_url.split('//')[1].include?('localhost')
      'http://localhost:8080'
    elsif request.base_url.split('//')[1].include?('qa.blubirch.com')
      'http://qa.blubirch.com:3780'
    elsif request.base_url.split('//')[1].include?('croma-staging-api.blubirch.com')
      'https://croma-staging.blubirch.com'
    elsif request.base_url.split('//')[1].include?('qa-test.blubirch.com')
      'https://qa-test.blubirch.com'
    elsif request.base_url.split('//')[1].include?('demoext-reverse.blubirch.com')
      'https://demoext-reverse.blubirch.com'
    elsif request.base_url.split('//')[1].include?('qa-docker.blubirch.com')
      'https://qa-docker.blubirch.com:3780'
    elsif request.base_url.split('//')[1].include?('ramp20-api.blubirch.com')
      'https://ramp20.blubirch.com'
    else
      Rails.application.credentials.rims_base_url
    end
  end

  def request_base_url
    request.original_url.gsub(request.path, "")
  end

  def render_collection resources, serializer
    render json: resources, each_serializer: serializer,  meta: pagination_meta(resources)
  end

  def render_error message, status
    render json: { error: message }, status: status
  end

  def render_error_with_backtrace message, backtrace, status
    render json: { error: message, backtrace: backtrace }, status: status
  end

  def render_success_message message, status
    render json: { message: message }, status: status
  end

  def render_collection resources, serializer
    render json: resources, each_serializer: serializer,  meta: pagination_meta(resources)
  end

  def render_resource resource, serializer
    render json: resource, serializer: serializer
  end

  def render_collection_without_pagination resources, serializer
    render json: resources, each_serializer: serializer
  end

  def get_distribution_centers(disposition_name = "Liquidation")
    @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @distribution_center_detail = ""
    if ["Default User", "Site Admin"].include?(current_user.roles.last.name) || is_standalone_application?
      ids = @distribution_center.present? ?  [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
      current_user.distribution_center_users.where(distribution_center_id: ids).each do |distribution_center_user|
        @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == disposition_name || d["disposition"] == "All"}.last
        if @distribution_center_detail.present?
          @distribution_center_ids = @distribution_center_detail["warehouse"].include?(0) ? DistributionCenter.all.pluck(:id) : @distribution_center_detail["warehouse"]
          return
        end
      end
    else
      @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : DistributionCenter.all.pluck(:id)
    end
  end

  private

  def handle_exception(exception)
    if exception.class == CustomErrors
      render_unprocessable_entity(exception)
    elsif exception.class ==  JWT::VerificationError
      not_authorized
    elsif exception.class == ActionController::RoutingError
      respond_to do |format|
        format.json { render json: { error: 'Route not found' }, status: :not_found }
        format.html do
          redirect_to "#{root_url}404"
        end
      end
    elsif exception.class == ActiveRecord::RecordNotFound
      render json: { message: "Not Found", error: exception.message }, status: 500
    elsif exception.class == ActiveRecord::RecordInvalid
      render json: { message: "Bad Request", error: exception.message }, status: 500
    else
      Rails.logger.error(exception.message)
      respond_to do |format|
        format.json { render json: { error: exception.message }, status: 500 }
        format.html { render json: { error: exception.message }, status: 500 }
        # format.html do
        #   redirect_to "#{root_url}500"
        # end
      end
    end
  end
end
