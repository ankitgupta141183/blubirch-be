class Admin::RolesController < ApplicationController

  before_action :set_role, only: [:show, :update, :destroy, :edit]

  def index
    set_pagination_params(params)
    @roles = Role.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @roles, meta: pagination_meta(@roles)
  end

  def show
    render json: @role
  end

  def create
		@role = Role.new(role_params)
		if @role.save
			render :json => @role
		else
			render json: @role.errors, status: :unprocessable_entity
		end
	end

  def edit
    render json: @role
  end

  def update
    if @role.update(role_params)
      render json: @role
    else
      render json: @role.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @role.destroy
  end

	private

	def role_params
    params.require(:role).permit(:name, :code)
  end

  def set_role
    @role = Role.find(params[:id])
  end

  def filtering_params
    params.slice(:name, :code)
  end

end
