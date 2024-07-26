class Api::V2::AccountSettingsController < ApplicationController
  def show
    render json: { account_setting: AccountSetting.first }
  end
end
