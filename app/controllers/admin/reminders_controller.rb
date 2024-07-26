class Admin::RemindersController < ApplicationController
  before_action :set_reminder, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @reminders = Reminder.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @reminders, meta: pagination_meta(@reminders)
  end

  def show
    render json: @reminder
  end

  def create
    @reminder = Reminder.new(reminder_params)

    if @reminder.save
      render json: @reminder, status: :created
    else
      render json: @reminder.errors, status: :unprocessable_entity
    end
  end

  def update
    if @reminder.update(reminder_params)
      render json: @reminder
    else
      render json: @reminder.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @reminder.destroy
  end

  def import
    @reminder = Reminder.import(params[:file])
    render json: @reminder
  end

  private
    def set_reminder
      @reminder = Reminder.find(params[:id])
    end

    def reminder_params
      params.require(:reminder).permit(:status_id, :client_category_id, :customer_return_reason_id, :sku_master_id, :approval_required, :deleted_at, details: {})
    end

    def filtering_params
      params.slice(:status_id,:client_category_id, :customer_return_reason_id, :sku_master_id, :approval_required)
    end
end
