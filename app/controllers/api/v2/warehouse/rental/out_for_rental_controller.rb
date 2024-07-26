class Api::V2::Warehouse::Rental::OutForRentalController < Api::V2::Warehouse::RentalsController
  STATUS = 'Out For Rental'

  def index
    @rentals = @rentals.order('updated_at desc').page(@current_page).per(@per_page)
    render_collection(@rentals, Api::V2::Warehouse::OutForRentalSerializer)
  end

  def update_rental
    rental_emi = RentalEmi.find_by(id: params[:id])
    respond_with_error('No Rental Emi detail found.') and return if rental_emi.blank?
    if rental_emi.update(received_rental: params[:received_rental], received_date: Date.today)
      respond_with_success('Rental is updated.')
    else
      respond_with_error(rental_emi.errors.full_messages.join(','))
    end
  end
  private
  
end
