class Admin::ClientsController < ApplicationController
  
  before_action :set_client, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @clients = Client.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @clients, meta: pagination_meta(@clients)
  end

  def show
    render json: @client
  end

  def create
    @client = Client.new(client_params)

    if @client.save
      render json: @client, status: :created
    else
      render json: @client.errors, status: :unprocessable_entity
    end
  end

  def update
    if @client.update(client_params)
      render json: @client
    else
      render json: @client.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy
  end

  def search
    set_pagination_params(params)
    if params[:search_params]
      parameter = params[:search_params].downcase
      @search_results = Client.all.where("lower(name) LIKE :search_params", search_params: "%#{parameter}%").page(@current_page).per(@per_page)
      render json: @search_results, meta: pagination_meta(@search_results)
    else
      render json: @search_results.errors, status: :unprocessable_entity
    end
  end

  private
    def set_client
      @client = Client.find(params[:id])
    end

    def client_params
      params.require(:client).permit(:name, :domain_name, :deleted_at)
    end

    def filtering_params
      params.slice(:name,:domain_name)
    end
end
