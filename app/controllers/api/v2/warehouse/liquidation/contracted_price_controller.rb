class Api::V2::Warehouse::Liquidation::ContractedPriceController < Api::V2::Warehouse::LiquidationsController
  STATUS = 'Contracted Price'

  before_action :validate_lot_params, only: :create_lot

  def create_lot
    lot = LiquidationOrder.create_lot(lot_params, current_user)
    render_success_message("Lot creation successful with the ID \"#{lot.id}\" & updated in the ‘Pending Payment’ page", :ok)
  rescue => e
    render_error(e.message, 500)
  end

  def get_vendor_contract
    vendor_masters = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': 'Contracted Liquidation').distinct
    render_collection_without_pagination(vendor_masters, Api::V2::Warehouse::VendorMasterSerializer)
  end

  private

  def lot_params
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_contract_lot)
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_payment)
    lot_params = {
                    lot: {
                      lot_name: params[:lot_name],
                      lot_type: lot_type.original_code,
                      lot_type_id: lot_type.id,
                      status: lot_status.original_code,
                      status_id: lot_status.id,
                      winner_code: params[:assigned_buyer],
                      vendor_code: params[:assigned_buyer],
                      winner_amount: @winner_amount,
                      start_date: Time.now.strftime("%F %I:%M:%S %p"),
                      end_date: Time.now.strftime("%F %I:%M:%S %p"),
                      created_by_id: current_user.id
                    },
                    liquidation_ids: params[:liquidation_ids],
                  }
    if params[:lot_file].present?
      lot_file = CSV.read(params[:lot_file].path, headers: true, header_converters: :symbol)
      lot_params[:liquidation_ids] = lot_file[:article_id]&.map(&:strip)
      lot_params[:lot][:lot_name] = lot_file[:lot_name][0]
      lot_params[:buyer_id] = lot_file[:assigned_buyer][0]
    end
    lot_params
  end

  def validate_lot_params
    render_error("Missing required param 'assigned_buyer'.", 422) and return if params[:assigned_buyer].blank?

    render_error("Missing required param 'lot_name'.", 422) and return if lot_params[:lot][:lot_name].blank?

    liquidations = Liquidation.where(id: lot_params[:liquidation_ids])
    render_error("No liquidations found!", 422) and return if liquidations.blank?

    ewaste_statuses = liquidations.pluck(:is_ewaste)
    if ewaste_statuses.include?("yes") && (ewaste_statuses.include?("no") || ewaste_statuses.include?("not_defined"))
      render_error("e-waste item and an item marked as non e-waste can’t be part of the same lot'.", 422) and return
    end

    liquidations_with_invalid_status = liquidations.where.not(status: self.class::STATUS)
    render_error("Contains Liquidations which are not in '#{self.class::STATUS}'. ", 422) and return if liquidations_with_invalid_status.present?

    vendor_master = VendorMaster.where(vendor_code: params[:assigned_buyer]).includes(:vendor_rate_cards).last
    missing_rate_cards = []
    @winner_amount = 0
    liquidations.each do |liquidation|
      rate_card = vendor_master.vendor_rate_cards.find_by(sku_master_code: liquidation.sku_code, item_condition: liquidation.grade)
      if rate_card
        @winner_amount += rate_card.contracted_rate
      else
        missing_rate_cards << liquidation.tag_number
      end
    end
    render_error("Please update rate card for item(s) #{missing_rate_cards.join(',')}.", 422) and return if missing_rate_cards.present?
  end
end
