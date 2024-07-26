class Admin::EmailTemplatesController < ApplicationController

  before_action :set_email_template, only: [:show, :update, :destroy, :edit]

  def index
    set_pagination_params(params)
    @email_templates = EmailTemplate.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @email_templates, meta: pagination_meta(@email_templates)
  end

  def show
    render json: @email_template
  end

  def create
    @email_template = EmailTemplate.new(email_template_params)
    if @email_template.save
      render :json => @email_template, status: :created
    else
      render json: @email_template.errors, status: :unprocessable_entity
    end
  end

  def edit
    render json: @email_template
  end

  def update
    if @email_template.update(email_template_params)
      render json: @email_template
    else
      render json: @email_template.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @email_template.destroy
  end

  def import
    @email_template = EmailTemplate.import(params[:file])
    render json: @email_template
  end

  private

  def email_template_params
    params.require(:email_template).permit(:name, :template, :template_type_id, :deleted_at)
  end

  def set_email_template
    @email_template = EmailTemplate.find(params[:id])
  end

  def filtering_params
    params.slice(:name, :template, :template_type_id)
  end

end
