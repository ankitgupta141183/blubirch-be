class Api::V2::OndcsController < ApplicationController
  skip_before_action :authenticate_user!, :check_permission

  def register

  end

  # ? POST - /api/v2/ondc/on_search
  def on_search
    data = Ondc::OnSearchService.new.full_catalog
    render json: data 
  end

  # ? POST - /api/v2/ondc/on_select
  def on_select
    data = Ondc::OnSelectService.new(params).get_selected_records
    render json: data
  end

  # ? POST - /api/v2/ondc/on_init
  def on_init

  end

  # ? POST - /api/v2/ondc/on_confirm
  def on_confirm
    data = Ondc::OnConfirmService.new(params).on_confirm
    render json: data
  end

  # ? POST - /api/v2/ondc/on_status
  def on_status

  end

  # ? POST - /api/v2/ondc/on_cancel
  def on_cancel
    data = Ondc::OnCancelService.new(params).on_cancel
    render json: data
  end

  # ? POST - /api/v2/ondc/on_update
  def on_update

  end

  # ? POST - /api/v2/ondc/on_track
  def on_track

  end

end
