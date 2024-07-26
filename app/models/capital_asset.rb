class CapitalAsset < ApplicationRecord

  include CapitalAssetSearchable
  include Filterable

  belongs_to :inventory, class_name: 'ForwardInventory'
  belongs_to :distribution_center

  has_many :capital_asset_histories
  has_many :approval_requests, as: :approvable

  scope :filter_by_tag_id, -> (tag_id){ where(tag_number: tag_id) }
  scope :filter_by_article_id, -> (article_id){ where(article_sku: article_id) }
  scope :filter_by_assignment_status, -> (assignment_status){ where(assignment_status: assignment_status) }

	enum assignment_status: { assigned: 1, unassigned: 2 }, _prefix: true

  def self.create_record(forward_inventory, user_id = nil)
    ActiveRecord::Base.transaction do
      user = user_id.present? ? User.find_by_id(user_id) : nil

      status = LookupValue.find_by_code(Rails.application.credentials.capital_asset_status_assets)
      record = self.new
      record.inventory_id = forward_inventory.id
      record.tag_number = forward_inventory.tag_number
      record.distribution_center_id = forward_inventory.distribution_center_id
      record.article_sku = forward_inventory.sku_code
      record.article_description = forward_inventory.item_description
      record.details = forward_inventory.details
      record.status_id = status.id
      record.status = status.original_code
      record.client_id = forward_inventory.client_id
      record.client_tag_number = forward_inventory.client_tag_number
      record.brand = forward_inventory.details["brand"]
      record.client_category_id = forward_inventory.client_category_id
      record.is_active = true
      record.assignment_status = 'unassigned'
      record.save

      if record.save
        ih = record.capital_asset_histories.new(status_id: record.status_id)
        ih.details = {}
        ih.details['capital_asset_created_at'] = Time.now.to_s
        ih.details["status_changed_by_user_id"] = user.try(:id)
        ih.details["status_changed_by_user_name"] = user.try(:full_name)
        ih.save
      end

      forward_inventory.update_inventory_status(status)
    end
  end
end
