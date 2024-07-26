class Cannibalization < ApplicationRecord
  include CannibalizationSearchable
  include Filterable
  include GenerateTagNumber

  default_scope { where(is_active: true) }
  belongs_to :inventory
  belongs_to :distribution_center
  has_many :sub_cannibalize_items, class_name: 'Cannibalization', foreign_key: :parent_id, dependent: :destroy
  belongs_to :parent_cannibalize_item, class_name: 'Cannibalization', foreign_key: :parent_id, optional: true
  has_many :cannibalization_histories

  scope :filter_by_tag_id, ->(tag_id) { where(tag_number: tag_id) }
  scope :filter_by_article_id, ->(article_id) { where(sku_code: article_id) }
  scope :filter_by_condition, ->(condition) { where(condition: condition) }
  scope :filter_by_article_type, ->(article_type) { where(article_type: article_type) }
  scope :filter_by_uom, ->(uom) { where(uom: uom) }

  scope :only_view_bom, -> { where(status: ["Work In Progress Item", "To Be Cannibalized Item"]) }
  scope :only_work_in_progress, -> { where(status: "Work In Progress") }
  scope :only_work_in_progress_and_cannibalized, -> { where(status: ["Work In Progress", "Cannibalized"]) }

  def self.create_cannibalize_record(inventory, user_id)
    ActiveRecord::Base.transaction do
      bom_mappings = inventory.get_bom_mappings

      raise CustomErrors, "Can't be cannibalized inventory does not have BOM mappings." unless bom_mappings.present?

      if user_id.present?
        user = User.find_by_id(user_id)
      else
        user = inventory.user
      end

      status = LookupValue.find_by_code('cannibalization_status_to_be_cannibalized')
      item_status = LookupValue.find_by_code('cannibalization_status_to_be_cannibalized_item')

      parent_cannibalize_item = Cannibalization.create_record(inventory, status, user)
      parent_cannibalize_item.create_cannibalization_history(user)

      bom_mappings.each do |bom|
        bom_inventory = Inventory.create(tag_number: parent_cannibalize_item.generate_valid_tag_number, client_category_id: inventory.client_category_id, client_id: inventory.client_id, client_tag_number: inventory.client_tag_number, gate_pass_id: inventory.gate_pass_id, gate_pass_inventory_id: inventory.gate_pass_inventory_id, quantity: bom.quantity, sku_code: bom.sku_code, status: inventory.status, status_id: inventory.status_id, distribution_center_id: inventory.distribution_center_id, details: inventory.details.merge({ parent_cannibalize_id: parent_cannibalize_item.id, parent_inventory_id: inventory.id, bom_mapping_id: bom.id }))
        child_cannibalize_item = Cannibalization.create_record(bom_inventory, item_status, user, bom, parent_cannibalize_item.id)
      end
    end
  end

  def self.create_record(inventory, status, user, bom = nil, parent_id = nil)
    record = self.new
    record.inventory_id = inventory.id
    record.tag_number = inventory.tag_number
    record.sku_code = inventory.sku_code
    record.item_description = inventory.item_description
    record.distribution_center_id = inventory.distribution_center_id
    record.details = inventory.details
    record.status_id = status.id
    record.status = status.original_code
    if bom.present?
      record.uom = bom.uom
      record.quantity = bom.quantity
      record.parent_id = parent_id
      record.bom_article_id = bom.bom_article_id
      record.client_sku_master_id = bom.client_sku_master_id
    end
    record.is_active = true

    if record.save
      record.create_cannibalization_history(user)
    end
    record
  end

  def move_to_work_in_progress_tab(params, sub_cannibalize_item_child, user)
    parent_item = parent_cannibalize_item
    status = LookupValue.find_by(code: 'cannibalization_status_work_in_progress')
    sub_status = LookupValue.find_by(code: "cannibalization_status_work_in_progress_item")
    actual_quantity = quantity.to_i + sub_cannibalize_item_child.try(:quantity).to_i
    cannibalization_details = {quantity: params[:quantity].to_i, tag_number: params[:tag_id].presence || generate_valid_tag_number, tote_id: params[:tote_id], condition: params[:condition], status_id: status.id, status: status.original_code, is_active: true}
    cannibalization_details.merge!({is_active: false}) if params[:condition] == "Write Off"
    cannibalization_details, inv_status = if actual_quantity != params[:quantity].to_i
      new_sub_cannibalize_item = create_new_cannibalization_and_inventory(sub_cannibalize_item_child, cannibalization_details)
      new_sub_cannibalize_item.create_cannibalization_history(user)
      [{quantity: actual_quantity - params[:quantity].to_i, tag_number: tag_number.presence || generate_valid_tag_number, status_id: sub_status.id, status: sub_status.original_code, is_active: true}, {status: new_sub_cannibalize_item&.inventory&.status, status_id: new_sub_cannibalize_item&.inventory&.status_id}]
    elsif sub_cannibalize_item_child.present?
      inv_status = LookupValue.find_by(code: Rails.application.credentials.inventory_status_warehouse_closed_successfully)
      sub_cannibalize_item_child.update!(cannibalization_details)
      sub_cannibalize_item_child.inventory.update!(tag_number: cannibalization_details[:tag_number])
      sub_cannibalize_item_child.create_cannibalization_history(user)
      [{quantity: 0, status_id: sub_status.id, status: sub_status.original_code, is_active: false}, {status: inv_status.original_code, status_id: inv_status.id}]
    else
      [cannibalization_details, {}]
    end
    update!(cannibalization_details)
    inventory.update!(inv_status.merge({tag_number: self.tag_number}))
    create_cannibalization_history(user)
    return if parent_item.sub_cannibalize_items.any?
    parent_item.update!(
      status: status.original_code,
      status_id: status.id
      )
    parent_item.create_cannibalization_history(user)
  end

  def move_to_cannibalized_tab(user)
    status = LookupValue.find_by(code: "cannibalization_status_cannibalized")
    sub_status = LookupValue.find_by(code: "cannibalization_status_cannibalized_item")
    items_count = sub_cannibalize_items.only_view_bom.each do |sub_cannibalize_item|
      sub_cannibalize_item.update(status: sub_status.original_code, status_id: sub_status.id)
      sub_cannibalize_item.create_cannibalization_history(user)
    end
    update(
      is_active: !items_count.size.zero?,
      status: status.original_code,
      status_id: status.id
      )
    create_cannibalization_history(user)
    sub_cannibalize_items.only_work_in_progress.each do |sub_cannibalize_item|
      sub_cannibalize_item.update(status: status.original_code, status_id: status.id)
      sub_cannibalize_item.create_cannibalization_history(user)
    end
  end

  def create_cannibalization_history(user)
    ih = cannibalization_histories.new(status_id: status_id)
    ih.details['created_at'] = Time.now.to_s
    ih.details['status_changed_by_user_id'] = user.id
    ih.details['status_changed_by_user_name'] = user.full_name
    ih.details.merge!(previous_changes.except(:created_at, :updated_at))
    ih.save
  end

  def set_disposition(disposition, current_user)
    begin
      ActiveRecord::Base.transaction do
        inventory = self.inventory
        self.details['Cannibalization_set'] = true
        self.is_active = false
        inventory.details['cannibalized_processed'] = true
        inventory.disposition = disposition
        inventory.save

        sub_cannibalize_items.update_all(is_active: false) if sub_cannibalize_items.present?

        if self.save!
          create_cannibalization_history(current_user)
        end

        case disposition
        when "Production"
          # need clarification to change into forward inventory
          # DispositionRule.create_fwd_bucket_record(disposition, inventory, 'Cannibalization', current_user&.id)
        else
          DispositionRule.create_bucket_record(disposition, inventory, 'Cannibalization', current_user&.id)
        end
      end
    rescue ActiveRecord::RecordInvalid => exception
      render json: "Something Went Wrong", status: :unprocessable_entity
      return
    end
  end

  def generate_valid_tag_number
    number_is_valid = false
    until number_is_valid
      tag_number = generate_uniq_tag_number
      number_is_valid = validate_tag_uniqueness(tag_number, true)
    end
    tag_number
  end

  def create_new_cannibalization_and_inventory(sub_cannibalize_item_child, details = {})
    new_cannibalize_item = sub_cannibalize_item_child || dup
    new_inventory = Inventory.find_by("details ->> 'old_inventory_id' = '?' ", inventory.id) || inventory.dup
    new_inventory.details ||= {}
    new_inventory.details.merge!({old_inventory_id: inventory.id})
    new_inventory.tag_number = details[:tag_number]
    new_inventory.save!
    details[:inventory_id] = new_inventory.id
    new_cannibalize_item.details.merge!({old_cannibalization_id: id})
    new_cannibalize_item.update!(details)
    new_cannibalize_item
  end

  def ageing
    "#{(Date.today.to_date - created_at.to_date).to_i}D" rescue "0D"
  end

  def validate_tag_uniqueness(tag_number, check_inventory = false)
    validate_uniqueness(false, false, tag_number, 'Cannibalization', 'tag_number') && (check_inventory || validate_uniqueness(false, false, tag_number, 'Inventory', 'tag_number'))
  end

  def quantity_with_sub_cannibalize_items
    sub_cannibalize_item_child = Cannibalization.unscoped.find_by("details ->> 'old_cannibalization_id' = '?' ", id)

    quantity.to_i + sub_cannibalize_item_child.try(:quantity).to_i
  end

  def ready_to_be_cannibalized
    parent_id.nil? && sub_cannibalize_items.only_work_in_progress.any?
  end
end
