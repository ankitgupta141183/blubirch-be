module ApiResponses
  extend ActiveSupport::Concern

  # API success response
  def respond_with_object(obj)
    render json: obj, status: 200
  end

  def respond_with_success(message)
    render json: {message: message, type: "success"}, status: 200
  end

  # API error response
  def respond_with_error(error)
    render :json => {message: error, type: "error"}, :status => :unprocessable_entity
  end

  def common_response(message, status = 200, key = nil, data = nil, is_pagination = false )
    if key.present?
      if is_pagination.present?
        render json: {message: message, status: status, key => data, meta: pagination_meta(data)}, status: status
      else 
        render json: {message: message, status: status, key => data}, status: status
      end 
    else
      render json: {message: message, status: status}, status: status
    end
  end
end
