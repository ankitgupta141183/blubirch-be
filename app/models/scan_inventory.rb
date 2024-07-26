# frozen_string_literal: true

# scan tag number information for physical inspections
class ScanInventory < ApplicationRecord
  belongs_to :physical_inspection
  belongs_to :distribution_center

  def self.create_bulk_records(tag_ids, hash)
    tag_ids.each do |tag_id|
      ScanInventory.create(hash.merge({ tag_number: tag_id }))
    end
    true
  end
end
