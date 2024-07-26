class Admin::ChannelsController < ApplicationController
	before_action :set_channel, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
   @channels = Channel.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
   render json: @channels, meta: pagination_meta(@channels)
   
  end

  def show
   render json: @channel
  end

  def create
    @channel = Channel.new(channel_params)

    if @channel.save
      render json: @channel, status: :created
    else
      render json: @channel.errors, status: :unprocessable_entity
    end
  end

  def update
    if @channel.update(channel_params)
      render json: @channel
    else
      render json: @channel.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @channel.destroy
  end

  private
 
  def set_channel
    @channel = Channel.find(params[:id])
  end

  def channel_params
    params.require(:channel).permit(:distribution_center_id, :name, :cost_formula, :revenue_formula, :recovery_formula, :deleted_at)
  end

  def filtering_params
    params.slice(:name, :distribution_center_id)
  end

end
