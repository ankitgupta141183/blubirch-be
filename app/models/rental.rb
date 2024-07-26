# frozen_string_literal: true

# An Class for proving inventory on rent to the Vendor/Buyer
class Rental < ApplicationRecord
  include RentalSearchable
  include Filterable

  default_scope { where(is_active: true) }
  belongs_to :inventory, class_name: 'ForwardInventory'
  belongs_to :distribution_center
  belongs_to :lease_order, optional: true

  has_one :current_emi, -> { where('start_date <= ? AND end_date >= ?', Time.zone.today, Time.zone.today) }, class_name: 'RentalEmi'
  has_many :rental_histories
  has_many :rental_emis

  scope :filter_by_tag_id, ->(tag_id) { where(tag_number: tag_id) }
  scope :filter_by_article_id, ->(article_id) { where(article_sku: article_id) }

  before_update :generate_rental_emis, if: :status_changed_to_pending_payment?
  before_update :create_dispatch_order, if: :status_changed_to_out_for_rental?

  def self.create_record(forward_inventory, user_id)
    status = LookupValue.find_by(code: Rails.application.credentials.rental_status_reserve)
    disposition = LookupValue.find_by(code: 'forward_disposition_rental')
    ActiveRecord::Base.transaction do
      record                        = new
      record.inventory              = forward_inventory
      record.distribution_center_id = forward_inventory.distribution_center_id
      record.client_id              = forward_inventory.client_sku_master_id
      record.tag_number             = forward_inventory.tag_number
      record.article_sku            = forward_inventory.sku_code
      record.article_description    = forward_inventory.item_description
      record.details                = forward_inventory.details
      record.status_id              = status.id
      record.status                 = status.original_code
      record.quantity               = forward_inventory.quantity
      record.is_active              = true
      record.save!

      forward_inventory.update!(disposition: disposition.original_code, disposition_id: disposition.id)
      record.update_inventory_status(status, user_id)
    end
  end

  def update_inventory_status(status, user_id)
    raise CustomErrors, 'Invalid Status' if status.blank?

    inventory.update_inventory_status(status, user_id)
  end

  def create_history(user_id = nil)
    user = if user_id.present?
             User.find_by(id: user_id)
           else
             User.find_by(id: inventory.user_id)
           end
    status = LookupValue.find(status_id)
    details_key = "#{status.original_code.downcase.split(' ').join('_')}_created_date"
    rental_histories.create(status_id: status_id, details: { details_key => Time.zone.now.to_s, 'status_changed_by_user_id' => user&.id, 'status_changed_by_user_name' => user&.full_name })
  end

  def move_to_in_stock_saleable(current_user)
    Saleable.create_record(inventory, current_user.id)
    self.is_active = false
    save
  end

  def self.create_rental_reserve(rental_params, current_user)
    rentals = []
    generate_rental_id = "R-#{SecureRandom.hex(5)}"
    if rental_params[:item_details_by_tag_number].present?
      rental_params[:item_details_by_tag_number].each do |detail|
        tag_number = detail.delete(:tag_number)
        detail.merge!(rental_params.except(:item_details_by_tag_number))
        detail[:rental_reserve_id] = generate_rental_id
        rental = Rental.find_by(tag_number: tag_number)
        rental.update!(detail)
        rental.create_history(current_user&.id)
        rentals << rental
      end
    elsif rental_params[:item_details_by_article_number].present?
      rental_params[:item_details_by_article_number].each do |detail|
        article_number = detail.delete(:article_number)
        quantity = detail.delete(:quantity)
        detail.merge!(rental_params.except(:item_details_by_article_number))
        Rental.where(article_sku: article_number, status: 'Reserve').limit(quantity.to_i).each do |rental|
          detail[:rental_reserve_id] = generate_rental_id
          rental.update!(detail)
          rental.create_history(current_user&.id)
          rentals << rental
        end
      end
    end
    rentals
  end

  def change_disposition(disposition, current_user = nil)
    update!(is_active: false)

    DispositionRule.create_fwd_bucket_record(disposition, inventory, 'Rental', current_user&.id)
  end

  private

  def status_changed_to_out_for_rental?
    lookup_key = LookupKey.find_by(code: 'RENTAL_STATUS')
    lookup_value = lookup_key.lookup_values.find_by(code: 'rental_status_out_for_rental')
    status_changed? && status == lookup_value&.original_code.to_s
  end

  def status_changed_to_pending_payment?
    lookup_key = LookupKey.find_by(code: 'RENTAL_STATUS')
    lookup_value = lookup_key.lookup_values.find_by(code: 'rental_status_pending_payment')
    status_changed? && status == lookup_value&.original_code.to_s && rental_emis.blank?
  end

  def create_dispatch_order
    raise CustomErrors, 'Vendor code is not present in inventory' if buyer_code.blank?

    create_dispatch_items
  end

  def create_dispatch_items
    # 1. Creating Lease Order
    vendor_master = VendorMaster.find_by(vendor_code: buyer_code)
    lease_order = LeaseOrder.new(vendor_code: vendor_master.vendor_code)
    lease_order.order_number = "OR-Lease-#{SecureRandom.hex(6)}"
    lease_order.save!

    # 2. Update Rental Record
    self.lease_order_id = lease_order.id

    # 3. Create Warehouse Order
    warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.dispatch_status_pending_pickup)
    warehouse_order = lease_order.warehouse_orders.new(
      distribution_center_id: distribution_center_id,
      vendor_code: lease_order.vendor_code,
      reference_number: lease_order.order_number,
      client_id: client_id,
      status_id: warehouse_order_status.id,
      total_quantity: 1
    )
    warehouse_order.save!

    # 4. Create Warehouse Order Items and create history
    client_category = begin
      ClientSkuMaster.find_by(code: article_sku).client_category
    rescue StandardError
      nil
    end
    warehouse_order_item = warehouse_order.warehouse_order_items.new(
      forward_inventory_id: inventory_id,
      client_category_id: begin
        client_category.id
      rescue StandardError
        nil
      end,
      client_category_name: begin
        client_category.name
      rescue StandardError
        nil
      end,
      sku_master_code: article_sku,
      item_description: article_description,
      tag_number: tag_number,
      quantity: 1,
      status_id: warehouse_order_status.id,
      status: warehouse_order_status.original_code,
      serial_number: inventory.serial_number,
      aisle_location: aisle_location,
      # toat_number: toat_number,
      details: inventory.details,
      amount: lease_amount
    )
    warehouse_order_item.save!
  end

  def generate_rental_emis
    return unless lease_payment_frequency

    case lease_payment_frequency.downcase
    when 'weekly'
      emi_duration = 1.week
    when 'monthly'
      emi_duration = 1.month
    when 'yearly'
      emi_duration = 1.year
    else
      raise 'Invalid Payment Frequency'
    end

    emis_start_date = lease_start_date
    while emis_start_date <= lease_end_date
      emis_end_date = emis_start_date + emi_duration - 1

      rental_emis.create(
        start_date: emis_start_date,
        end_date: emis_end_date
      )
      emis_start_date = emis_end_date + 1
    end
  end
end
