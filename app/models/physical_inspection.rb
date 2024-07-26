# frozen_string_literal: true

# Models for Physical inspections of inventory
class PhysicalInspection < ApplicationRecord
  serialize :brands, Array
  serialize :category_ids, Array
  serialize :article_ids, Array
  serialize :dispositions, Array
  serialize :assignee_ids, Array
  serialize :sub_location_ids, Array
  belongs_to :distribution_center
  has_many :scan_inventories, dependent: :destroy
  has_many :issue_inventories, dependent: :destroy
  enum inventory_type: { all_invetory: 0, partial: 1 }
  enum status: { pending: 0, in_progress: 1, completed: 2 }
  scope :open_requests, -> { where.not(status: 2) }
  validates :request_id, :status, presence: true
  before_validation :set_status, :generate_uniq_request, on: :create
  before_save :update_assignee_ids
  before_update :create_issue_inventories, if: :status_changed_to_close?

  def self.select_columns
    joins(:distribution_center).select(:id, :request_id, :status, :created_at).select('distribution_centers.code as location')
  end

  def status_changed_to_close?
    status_changed? && status == 'completed'
  end

  def set_status
    self.status = :pending
  end

  def update_assignee_ids
    self.assignee_ids = assignees_hash&.keys
  end

  def generate_uniq_request
    self.request_id = SecureRandom.hex(4)
  end

  def location_name
    distribution_center&.name
  end

  def find_inventories
    sub_location_ids = self.sub_location_ids
    sub_location_ids = distribution_center.sub_locations.pluck(:id) unless sub_location_ids.present?
    Inventory.opened.where("distribution_center_id = ? OR sub_location_id IN (?)", distribution_center_id, sub_location_ids)
  end

  def create_issue_inventories
    IssueInventoryCreateWorker.perform_async(id)
    # scanned_inventories = scan_inventories
    # inventories = find_inventories
    # tag_numbers = scanned_inventories.pluck(:tag_number)
    # location = location_name
    # lookup_key = LookupKey.find_by(code: 'INWARD_STATUSES')
    # lookup_value = lookup_key.lookup_values.where(code: 'inward_statuses_pending_item_resolution').first
    # create_short_issue_items(tag_numbers, inventories, location)
    # create_excess_issue_items(tag_numbers, location)
    # create_pending_item(tag_numbers, location, lookup_value)
  end

  def create_short_issue_items(tag_numbers, inventories, location)
    create_issue_inventory(tag_numbers, location, inventories)
  end

  def create_excess_issue_items(tag_numbers, location)
    create_issue_inventory(tag_numbers, location)
  end

  def create_pending_item(tag_numbers, location, lookup_value)
    available_tags = Inventory.where(tag_number: tag_numbers).pluck(:tag_number)
    non_available_tag = tag_numbers - available_tags
    return unless non_available_tag.present?
    Item.where(tag_number: non_available_tag).update_all(location: location, status: lookup_value&.original_code, status_id: lookup_value&.id)
    # non_available_tag.each do |tag|
    #   item = Item.find_or_initialize_by(tag_number: tag)
    #   next unless item.new_record?
    #   item.location = location
    #   item.status = lookup_value&.original_code
    #   item.status_id = lookup_value&.id
    #   item.save(validate: false)
    # end
  end

  def create_issue_inventory(tag_numbers, location, inventories = nil)
    search_value = { tag_numbers: tag_numbers }
    not_condtion, search_with, inv_status = if inventories.present?
      [" NOT", nil, 0]
    else
      search_value.merge!({ distribution_center_id: distribution_center_id })
      [nil, " AND inventories.distribution_center_id != :distribution_center_id", 1]
    end
    data = (inventories || Inventory).joins("LEFT JOIN issue_inventories ON inventories.id = issue_inventories.inventory_id").where("inventories.tag_number#{not_condtion} IN (:tag_numbers)#{search_with} AND issue_inventories.inventory_id IS NULL", search_value).select("inventories.tag_number, inventories.id AS inventory_id").as_json
    data.each do |row|
      row.delete('id')
      row.merge!({
        physical_inspection_id: id,
        distribution_center_id: distribution_center_id,
        location: location,
        request_id: request_id,
        inventory_status: inv_status,
        status: 0,
        created_at: Time.zone.now,
        updated_at: Time.zone.now
      })
    end
    IssueInventory.insert_all(data) if data.present?
  end
end
