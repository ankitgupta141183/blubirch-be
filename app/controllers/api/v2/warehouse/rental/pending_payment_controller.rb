class Api::V2::Warehouse::Rental::PendingPaymentController < Api::V2::Warehouse::RentalsController
  STATUS = 'Pending Payment'

  def index
    @rentals = @rentals.order('updated_at desc').page(@current_page).per(@per_page)
    render_collection(@rentals, Api::V2::Warehouse::RentalPendingPaymentSerializer)
  end

  def update_status
    respond_with_error('Please select atlease 1 rental.') and return if params[:id].blank?
    
    rental = Rental.find_by(id: params[:id])
    respond_with_error('Rental is not found by provided id.') and return if rental.blank?

    lookup_key = LookupKey.find_by(code: 'RENTAL_STATUS')
    lookup_value = lookup_key.lookup_values.find_by(code: 'rental_status_out_for_rental')
    condition = params[:received_security_deposit].to_f == rental.security_deposit && params[:received_rental].to_f == rental.lease_amount
    respond_with_error('Lease Amount and Security Depostis must be same as expected.') and return if condition.blank?
    
    rental.status = lookup_value.original_code
    rental.status_id = lookup_value.id
    rental.details['received_security_deposit'] = params[:received_security_deposit]
    rental.details['received_rental'] = params[:received_rental]
    if rental.save
      rental.current_emi&.update(received_rental: params[:received_rental], received_date: Date.today)
      rental.create_history(current_user.id)
      respond_with_success("Payment successfully upadated for rental reserve ID '#{rental.rental_reserve_id}' and is move to 'Out for Rental' stage.")
    else
      respond_with_error(rental.errors.full_messages.join(','))
    end
  end

  def unreserve
    respond_with_error('Please select atlease 1 rental.') and return if params[:id].blank?
    ids = params[:id].split(",")
    rentals = Rental.where(id: ids)
    respond_with_error('Rental(s) are not found by provided ids.') and return if rentals.blank?

    # respond_with_error('Inventory can not be unreserve as partial payment is received.') and return if rental.details['received_security_deposit'].to_f > 0

    # rental.move_to_in_stock_saleable(current_user)
    lookup_key = LookupKey.find_by(code: 'RENTAL_STATUS')
    lookup_value = lookup_key.lookup_values.find_by(code: 'rental_status_reserve')
    rentals.each do |rental|
      rental.rental_emis.destroy_all
      rental.update(buyer_code: nil, status: lookup_value.original_code, status_id: lookup_value.id)
    end
    respond_with_success("#{rentals.count} item(s) moved back to rental tab.")
  end
  private
  
end
