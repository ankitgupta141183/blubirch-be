# frozen_string_literal: true

class Saleable < ApplicationRecord
  belongs_to :inventory, class_name: 'ForwardInventory'
  belongs_to :vendor, class_name: 'VendorMaster', optional: true
  belongs_to :sale_order, optional: true
  belongs_to :distribution_center

  has_many :payment_histories, as: :payable, dependent: :destroy
  has_many :saleable_histories, dependent: :destroy
  scope :dc_filter, ->(center_ids) { where(distribution_center_id: center_ids) }

  enum payment_status: { 'pending': 'pending', 'partial_paid': 'partial_paid', 'paid': 'paid' }, _prefix: true

  # ? Saleable.create_record(Inventory.last, nil)
  def self.create_record(inventory, user_id)
    status = LookupValue.find_by(code: 'saleable_status_in_stock')
    inventory_details = inventory.details
    item_inwarded_date = inventory_details['item_inwarded_date']
    ActiveRecord::Base.transaction do
      record                        = new
      record.is_active              = true
      record.article_sku            = inventory.sku_code
      record.inventory_id           = inventory.id
      record.article_description    = inventory.item_description
      record.details                = inventory_details.merge!({ serial_number: inventory.serial_number })
      record.details['criticality'] = 'Low'
      record.tag_number             = inventory.tag_number
      record.status_id              = status.id
      record.status                 = status.original_code
      record.selling_price          = (inventory.pending_receipt_document_item.sales_price rescue inventory.item_price)
      record.benchmark_date         = item_inwarded_date.presence || (Date.current - 3.days) # Currently considering it statuc
      record.payment_status         = 'pending'
      record.distribution_center_id = inventory.distribution_center_id
      record.location               = inventory.distribution_center.code
      record.vendor_code            = inventory.vendor&.vendor_code
      record.vendor_name            = inventory.supplier
      record.save

      record.reload
      record.create_history(user_id)

      inventory.update!(disposition: 'Saleable')
      inventory.update_inventory_status(status)
    end
  end

  def create_history(user_id = nil)
    begin
      user = User.find_by(id: user_id.presence || inventory.user_id)
    rescue StandardError
      user = nil
    end
    status = LookupValue.find(status_id)
    original_code = status.original_code
    details_key = "#{original_code.downcase.split(' ').join('_')}_created_date"
    saleable_histories.create(status: original_code, status_id: status_id,
                              details: { details_key => Time.zone.now.to_s, 'status_changed_by_user_id' => user&.id,
                                         'status_changed_by_user_name' => user&.full_name })
  end

  # & Saleable.send_items_to_dispatch(saleable_ids)
  def self.send_items_to_dispatch(saleable_ids)
    saleables = where("is_active = true AND status = 'Pending Payment' AND payment_status = 'paid' and id IN (?)", saleable_ids)
    raise 'No saleables records' if saleables.blank?

    begin
      ActiveRecord::Base.transaction do
        saleable_first_rec = saleables.first
        saleable_order = SaleOrder.new(vendor_code: saleable_first_rec.vendor_code)
        saleable_order.order_number = "OR-Saleable-#{SecureRandom.hex(6)}"
        saleable_order.save!

        credentails = Rails.application.credentials
        next_status = LookupValue.find_by(code: credentails.saleable_status_dispatch).original_code
        next_status_id = LookupValue.find_by(original_code: next_status).try(:id)
        saleables.find_each { |saleable| saleable.update!(sale_order_id: saleable_order.id, status: next_status, status_id: next_status_id) }

        warehouse_order_status = LookupValue.find_by(code: credentails.dispatch_status_pending_pickup)
        warehouse_order_status_id = warehouse_order_status.id

        warehouse_order = saleable_order.warehouse_orders.new(
          distribution_center_id: saleable_first_rec.distribution_center_id,
          vendor_code: saleable_order.vendor_code,
          reference_number: saleable_order.order_number,
          client_id: saleables.last.inventory.client_id,
          status_id: warehouse_order_status_id,
          total_quantity: saleables.count
        )
        warehouse_order.save!

        saleables.each do |saleable|
          # & Creating saleable history
          saleable.create_history(nil)
          # repair.update_inventory_status(next_status)
          article_sku = saleable.article_sku
          saleable_inv = saleable.inventory
          begin
            client_category = ClientSkuMaster.find_by(code: article_sku).client_category
            client_category_id, client_category_name = client_category.attributes.values_at('id', 'name')
          rescue StandardError
            client_category_id, client_category_name = nil
          end
          warehouse_order_item = warehouse_order.warehouse_order_items.new(
            forward_inventory_id: saleable.inventory_id,
            client_category_id: client_category_id,
            client_category_name: client_category_name,
            sku_master_code: article_sku,
            item_description: saleable.article_description,
            tag_number: saleable.tag_number,
            quantity: 1,
            status_id: warehouse_order_status_id,
            status: warehouse_order_status.original_code,
            serial_number: saleable_inv.serial_number,
            details: saleable_inv.details
          )
          warehouse_order_item.save!
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      raise e.message.to_s
    end
  end

  def create_payment_history(user, paid_amount)
    payment_histories.create!({ amount: paid_amount, paid_user: user.username, payment_date: Date.current, user_id: user.id })
  end

  # Saleable.state_and_cities
  def self.state_and_cities
    Rails.cache.fetch('cache_state_and_cities_redis', expires_in: 1.hour) do
      hash = { 'states' => [], 'state_map_with_cities' => {} }
      file = File.new(Rails.root.join('public/master_files/location_master_sheet.csv')) if file.nil?
      CSV.foreach(file.path, headers: true) do |row|
        state = row['state'].strip
        city = row['city'].strip

        state_map_with_cities_hash = hash['state_map_with_cities']
        states_hash = hash['states']

        states_hash << state if states_hash.exclude?(state)
        state_map_with_cities_hash[state] = [] unless state_map_with_cities_hash.keys.include?(state)
        state_map_with_cities_hash[state] << city
      end
      hash
    end
  end

  # & Saleable.generate_reserve_number
  def self.generate_reserve_number
    res_number = ''
    loop do
      res_number = rand(1_000_000_000..9_999_999_999)
      break if Saleable.find_by(reserve_number: res_number).blank?
    end
    res_number
  end
end
