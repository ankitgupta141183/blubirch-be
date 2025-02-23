module RecordAccessible
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: ->{ render json: { error: "Not Found" }, status: 404 }
    rescue_from ActiveRecord::RecordInvalid, with: ->{ render json: { error: "Bad Request" }, status: 400 }
    rescue_from Exception, with: :handle_exception
  end
end
