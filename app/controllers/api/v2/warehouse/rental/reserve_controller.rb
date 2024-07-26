class Api::V2::Warehouse::Rental::ReserveController < Api::V2::Warehouse::RentalsController
  STATUS = 'Reserve'

  before_action :validate_rental_reserve_params, :validate_vendor_and_rentals, only: %i[create_rental_reserve]
  before_action :set_rentals, only: %i[change_disposition]

  def get_dispositions
    lookup_key = LookupKey.find_by(code: 'FORWARD_DISPOSITION')
    dispositions = lookup_key.lookup_values.where(original_code: %w[Saleable Production Demo Usage Replacement]).as_json(only: %i[id original_code])
    render json: { dispositions: dispositions }
  end

  def create_rental_reserve
    begin
      ActiveRecord::Base.transaction do
        rentals = Rental.create_rental_reserve(@rental_reserve_params, current_user)
        render_success_message("Rental reserve ID \"#{rentals.last&.rental_reserve_id}\" created in the 'Pending Payment' stage.", :ok)
      end
    rescue => e
      render_error(e.message, 500)
    end
  end

  def vendor_master_details
    vendor_masters = VendorMaster.all.map{|vendor| {vendor_name: vendor.vendor_name, vendor_code: vendor.vendor_code}}
    render json: {vendor_masters: vendor_masters}
  end

  def article_ids_with_quantity
    article_ids_with_quantity = Rental.where(status: self.class::STATUS).group(:article_sku).size.map{|k, v| {article_id: k, quantity: v}} rescue {}
    render json: { article_ids_with_quantity: article_ids_with_quantity }, status: 200
  end

  def change_disposition
    ActiveRecord::Base.transaction do
      disposition = LookupValue.find_by(id: params[:disposition_id])
      raise CustomErrors, "Disposition can't be blank" if disposition.blank?

      @rentals.each do |rental|
        rental.change_disposition(disposition.original_code, current_user)
      end

      render json: { message: "#{@rentals.size} item(s) moved to #{disposition.original_code} disposition" }
    end
  end

  private

  def rental_reserve_params
    rental_status = LookupValue.find_by(code: Rails.application.credentials.rental_status_pending_payment)
    @rental_reserve_params = {
      buyer_code: params[:buyer_code],
      lease_payment_frequency: params[:lease_payment_frequency],
      lease_start_date: params[:lease_start_date],
      lease_end_date: params[:lease_end_date],
      notice_period_days: params[:notice_period_days],
      status: rental_status&.original_code,
      status_id: rental_status&.id
    }

    @value = (params[:item_details_by_tag_number].presence || params[:item_details_by_article_number].presence).map!{|item_detail| item_detail.to_h}
    @key = params.to_h.key(@value).to_sym

    @rental_reserve_params.merge!({ @key => @value })
  end

  def validate_rental_reserve_params
    params.permit!
    rental_reserve_params
    permit_params = [ :buyer_code, :lease_payment_frequency, :lease_start_date, :lease_end_date, :notice_period_days ]
    fields = if @rental_reserve_params[:item_details_by_tag_number].present?
      [:tag_number]
    elsif @rental_reserve_params[:item_details_by_article_number].present?
      [:article_number, :unit_price, :quantity]
    end

    permit_params << {@key => [:lease_amount, :security_deposit] + fields.to_a }

    errors = []

    permit_params.each do |param|
      if param.is_a?(Hash)
        param.each do |key, value|
          value.each do |val|
            @rental_reserve_params[key].each do |v|
              errors << "'#{val.to_s.titleize}' can not be blank." if v[val].blank?
            end
          end
        end
      else
        errors << "'#{param.to_s.titleize}' can not be blank." if @rental_reserve_params[param].blank?
      end
    end

    return render_error(errors.uniq.join(' '), 500) if errors.present?
  end

  def validate_vendor_and_rentals
    errors = []
    vendor_name = VendorMaster.find_by_vendor_code(params[:buyer_code])&.vendor_name
    if vendor_name.present?
      @rental_reserve_params[:buyer_name] = vendor_name
    else
      errors << "Vendor not found with '#{params[:buyer_code]}' vendor code."
    end
    params_tag_numbers = @rental_reserve_params[@key].map{|detail| detail[:tag_number]}
    inventories_tag_numbers = Rental.where(tag_number: params_tag_numbers, buyer_code: nil).pluck(:tag_number)
    errors << "Rental not found with #{params_tag_numbers - inventories_tag_numbers} tag numbers." if (params_tag_numbers - inventories_tag_numbers).any?

    return render_error(errors.join(' '), 500) if errors.present?
  end

  def set_rentals
    @rentals = Rental.where(id: params[:ids], is_active: true)
    return render_error("Could not find rentals with IDs :: #{params[:ids]}", 422) if @rentals.blank?
  end
end
