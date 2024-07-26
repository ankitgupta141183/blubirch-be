class IssueInventoryCreateWorker
  include Sidekiq::Worker
  def perform(physical_inspection_id)
    physical_inspection = PhysicalInspection.find(physical_inspection_id)
    tag_numbers = physical_inspection.scan_inventories.pluck(:tag_number)
    inventories = physical_inspection.find_inventories
    location = physical_inspection.location_name
    lookup_value = LookupValue.find_by(code: 'inward_statuses_pending_item_resolution')
    physical_inspection.create_short_issue_items(tag_numbers, inventories, location)
    physical_inspection.create_excess_issue_items(tag_numbers, location)
    physical_inspection.create_pending_item(tag_numbers, location, lookup_value)
  end
end