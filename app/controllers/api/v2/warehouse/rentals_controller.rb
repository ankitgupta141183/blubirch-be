class Api::V2::Warehouse::RentalsController < ApplicationController

  before_action -> { set_pagination_params(params) }, only: :index
  before_action :filter_rental_items, :search_rental_items, only: [:index]

  def index
    @rentals = @rentals.order('updated_at desc').page(@current_page).per(@per_page)
    render_collection(@rentals, Api::V2::Warehouse::RentalSerializer)
  end

  private

  def search_rental_items
    @rentals = @rentals.search_by_text(params[:search_text]) if params[:search_text].present?
  end

  def filter_rental_items
    @rentals = Rental
    @rentals = @rentals.filter(params[:filter]) if params[:filter].present?
    @rentals = @rentals.where(is_active: true, status: self.class::STATUS)
  end  
end
