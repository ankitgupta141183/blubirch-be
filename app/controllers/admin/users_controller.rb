class Admin::UsersController < ApplicationController

	before_action :set_user, only: [:show, :update, :destroy, :edit]

	def index
	  set_pagination_params(params)
	  @users = User.filter(filtering_params).page(@current_page).per(@per_page)
	  if @users.present?
	  	render json: @users, meta: pagination_meta(@users)
		else
	  	render json: "Unable to fetch users", status: :unprocessable_entity
	 	end
	end

	def show
	 	@roles = @user.roles.collect(&:name)
	  render json: @user
	end

	def create
	  @user = User.new(user_params)  
	  
	  if @user.save
	    render json: @user, status: :created
	  else
	 	render json: @user.errors, status: :unprocessable_entity
	  end
	end

	def edit
    	render json: @user
  	end

	def update
	  if @user.update(user_params)
	    render json: @user
	  else
	    render json: @user.errors, status: :unprocessable_entity
	  end
	end
	
	def destroy
	  @user.destroy
	end

	def search
	  set_pagination_params(params)
	  if params[:search_params]
	    parameter = params[:search_params].downcase
	    @search_results = User.all.where("lower(username) LIKE :search_params", search_params: "%#{parameter}%").page(@current_page).per(@per_page)
	    render json: @search_results, meta: pagination_meta(@search_results)
	  else
	    render json: @search_results.errors, status: :unprocessable_entity
	  end
	end

	def get_username
	    @search_results = User.where(username: params[:username]).last
	    render json: @search_results
	end



	private

	  def set_user
	    @user = User.find(params[:id])
	  end

	  def user_params
	    params.require(:user).permit(:email, :first_name, :last_name, :username, :contact_no, :password, :password_confirmation, role_ids: [], distribution_center_ids: [])
	  end

	  def filtering_params
	    params.slice(:email, :first_name, :last_name, :username, :contact_no)
	  end

end
