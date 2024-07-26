# frozen_string_literal: true

class ForwardReplacement < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :forward_inventory
  belongs_to :client_sku_master, optional: true
  belongs_to :vendor, class_name: 'VendorMaster', optional: true
  belongs_to :inventory_status, class_name: 'LookupValue', foreign_key: :status_id
  has_many :payment_histories, as: :payable, dependent: :destroy

  enum payment_status: { pending: 1, partially_paid: 2, paid: 3 }, _prefix: true

  scope :dc_filter, ->(center_ids) { where(distribution_center_id: center_ids) }

  def self.create_record(forward_inventory, user_id)
    status = LookupValue.find_by(code: 'forward_replacement_status_in_stock')
    disposition = LookupValue.find_by(code: 'forward_disposition_replacement')
    ActiveRecord::Base.transaction do
      record                        = new
      record.forward_inventory      = forward_inventory
      record.client_id              = forward_inventory.client_id
      record.distribution_center_id = forward_inventory.distribution_center_id
      record.client_sku_master_id   = forward_inventory.client_sku_master_id
      record.vendor_id              = forward_inventory.vendor_id
      record.tag_number             = forward_inventory.tag_number
      record.sku_code               = forward_inventory.sku_code
      record.item_description       = forward_inventory.item_description
      record.serial_number          = forward_inventory.serial_number
      record.supplier               = forward_inventory.supplier
      record.grade                  = forward_inventory.grade
      record.details                = forward_inventory.details
      record.status_id              = status.id
      record.status                 = status.original_code
      record.item_price             = forward_inventory.item_price
      record.payment_status         = :pending
      record.is_active              = true
      record.save!

      forward_inventory.update!(disposition: disposition.original_code, disposition_id: disposition.id)
      record.update_inventory_status(status, user_id)
    end
  end

  def update_inventory_status(status, user_id)
    fwd_inv = forward_inventory
    raise CustomErrors, 'Invalid Status' if status.blank?

    fwd_inv.update_inventory_status(status, user_id)
  end

  def self.generate_reserve_id
    reserve_id = ''
    loop do
      reserve_id = SecureRandom.random_number(1_000_000)
      break if ForwardReplacement.find_by(reserve_id: reserve_id).blank?
    end
    reserve_id
  end

  def create_payment_history(user, paid_amount)
    payment_history = payment_histories.create!({
      amount: paid_amount,
      paid_user: user.username,
      payment_date: Date.current,
      user_id: user.id
    })
  end
  
  def reserve_item(buyer, pending_payment_status, selling_price)
    self.buyer = buyer.vendor_name
    self.buyer_id = buyer.id
    self.status = pending_payment_status.original_code
    self.status_id = pending_payment_status.id
    self.selling_price = selling_price.to_f
    self.reserved_date = Date.current
    self.reserve_id = ForwardReplacement.generate_reserve_id
    self.payment_status = :pending
    save!
  end

  def set_disposition(disposition, current_user = nil)
    raise CustomErrors, "Disposition can't be blank!" if disposition.blank?

    self.is_active = false
    save!

    DispositionRule.create_fwd_bucket_record(disposition, forward_inventory, 'Replacement', current_user&.id)
  end
end
