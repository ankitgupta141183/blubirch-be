# frozen_string_literal: true

class Restock < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :inventory
  has_many :restock_histories, dependent: :destroy
  has_many :restock_attachments, as: :attachable, dependent: :destroy
  belongs_to :transfer_order, optional: true
  scope :dc_filter, ->(center_ids) { where(distribution_center_id: center_ids) }

  def create_history(user_id)
    user = User.find_by(id: user_id)
    status = LookupValue.find(status_id)
    details = if status.original_code == 'Pending Restock Destination'
                {
                  'pending_restock_destination_created_date' => Time.zone.now.to_s,
                  'status_changed_by_user_id' => user.id,
                  'status_changed_by_user_name' => user.full_name
                }
              elsif status.original_code == 'Pending Restock Dispatch'
                {
                  'pending_restock_dispatch_created_date' => Time.zone.now.to_s,
                  'status_changed_by_user_id' => user.id,
                  'status_changed_by_user_name' => user.full_name
                }
              else
                {}
              end
    restock_histories.create(status_id: status_id, details: details)
  end

  def self.create_record(inventory, user_id)
    ActiveRecord::Base.transaction do
      user = user_id.present? ? User.find_by(id: user_id) : inventory.user

      status = LookupValue.where('original_code = ?', 'Pending Restock Destination').first

      record = new(
        status_id: status.id,
        status: status.original_code,
        distribution_center_id: inventory.distribution_center_id,
        tag_number: inventory.tag_number,
        sku_code: inventory.sku_code,
        item_description: inventory.item_description,
        inventory_id: inventory.id,
        details: inventory.details,
        brand: inventory.details['brand'],
        source_code: inventory.details['source_code'],
        grade: inventory.grade,
        serial_number: inventory.serial_number,
        client_id: inventory.client_id,
        client_tag_number: inventory.client_tag_number,
        aisle_location: inventory.aisle_location,
        toat_number: inventory.toat_number,
        item_price: inventory.item_price,
        serial_number_2: inventory.serial_number_2,
        sr_number: inventory.sr_number,
        client_category_id: inventory.client_category_id,
        category: inventory.details['category_l3'],
        is_active: true
      )
      record.details['criticality'] = 'Low'

      if record.save
        rh = record.restock_histories.new(status_id: record.status_id)
        rh.details = {}
        rh.details['status_changed_by_user_id'] = user&.id
        rh.details['status_changed_by_user_name'] = user&.full_name
        rh.save
      end
    end
  end
end
