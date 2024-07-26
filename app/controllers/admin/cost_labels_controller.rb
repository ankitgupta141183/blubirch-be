class Admin::CostLabelsController < ApplicationController
  before_action :set_cost_label, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @cost_labels = CostLabel.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @cost_labels, meta: pagination_meta(@cost_labels)
  end

  def show
    render json: @cost_label
  end

  def create
    @cost_label = CostLabel.new(cost_label_params)

    if @cost_label.save
      render json: @cost_label, status: :created
    else
      render json: @cost_label.errors, status: :unprocessable_entity
    end
  end

  def update
    if @cost_label.update(cost_label_params)
      render json: @cost_label
    else
      render json: @cost_label.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @cost_label.destroy
  end

  private
    def set_cost_label
      @cost_label = CostLabel.find(params[:id])
    end

    def cost_label_params
      params.require(:cost_label).permit(:distribution_center_id, :channel_id, :label, :deleted_at)
    end

    def filtering_params
      params.slice(:distribution_center_id, :channel_id,:label)
    end
end
