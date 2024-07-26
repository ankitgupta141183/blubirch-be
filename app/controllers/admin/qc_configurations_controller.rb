class Admin::QcConfigurationsController < ApplicationController
  before_action :set_qc_configuration, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @qc_configurations = QcConfiguration.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @qc_configurations, meta: pagination_meta(@qc_configurations)
  end

  def show
    render json: @qc_configuration
  end

  def create
    @qc_configuration = QcConfiguration.new(qc_configuration_params)

    if @qc_configuration.save
      render json: @qc_configuration, status: :created
    else
      render json: @qc_configuration.errors, status: :unprocessable_entity
    end
  end

  def update
    if @qc_configuration.update(qc_configuration_params)
      render json: @qc_configuration
    else
      render json: @qc_configuration.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @qc_configuration.destroy
  end

  def import
    @qc_configuration = QcConfiguration.import(params[:file])
    render json: @qc_configuration
  end

  private
    def set_qc_configuration
      @qc_configuration = QcConfiguration.find(params[:id])
    end

    def qc_configuration_params
      params.require(:qc_configuration).permit(:distribution_center_id, :sample_percentage)
    end

    def filtering_params
      params.slice(:distribution_center_id,:sample_percentage)
    end
end
