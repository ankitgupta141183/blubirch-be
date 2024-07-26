class Api::V1::PasswordResetsController < ApplicationController

	skip_before_action :authenticate_user!
	skip_before_action :check_permission
	
	def send_otp
		user = User.find_by(email: params[:email].to_s.downcase)
		if user
			reset_otp = Random.rand(999 ... 10000)
			ResetPasswordWorker.perform_async(user.email,reset_otp)
			render json: {otp: reset_otp, status: :ok}
		else
			render json: {message: "User not found", status: :unprocessable_entity}
		end
	end

	def edit
		user = User.find_by(email: params[:email].to_s.downcase)
		if user
			user.generate_password_token!
			token =  user.reset_password_token
			render json: token, status: :ok
		else
			render json: {message: "User not found", status: :unprocessable_entity}
		end
	end

	def reset
    token = params[:token].to_s
    if params[:email].blank? || token.blank?
      return render json: {error: 'Token not present'}
    end
    user = User.find_by(reset_password_token: token)
    if user.present? && user.password_token_valid?
      if user.reset_password!(params[:password])
      	render json: {message: "Password successfully updated", status: 200}
      else
        render json: {error: user.errors.full_messages, status: :unprocessable_entity}
      end
    else
      render json: {error:  ['Error in reseting password'], status: :not_found}
    end
  end

  def change_password
  	user = User.find_by(email: params[:email])
  	if user.present?
      if user.reset_password!(params[:password])
      	render json: {message: "Password successfully updated", status: 200}
      else
        render json: {error: user.errors.full_messages, status: :unprocessable_entity}
      end
  	end
  end

end
