class Api::V1::SessionsController < Devise::SessionsController

	skip_before_action :verify_signed_out_user
  before_action :decode_credentials, only: [:create]
  
  respond_to :json

  private

  def decode_credentials
    if params[:user] && params[:user][:credentials]
      decoded_credentials = decode_utf8_b64(params[:user][:credentials])
      login, password = decoded_credentials.split(':').map(&:to_s)

      params[:user][:login] = login
      params[:user][:password] = password
      request.params.merge!("user": {"login": login, "password": password})
    end
  end

  def decode_utf8_b64(string)
    URI.unescape(CGI::escape(Base64.decode64(string)))
  end

  def respond_with(resource, _opts = {})
    render json: resource
  end

  def respond_to_on_destroy
    head :no_content
  end

end