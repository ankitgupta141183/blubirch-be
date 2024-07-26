class CreateDispatchBoxes < ActiveRecord::Migration[6.0]
  def change
    create_table :dispatch_boxes do |t|
      t.string   :box_number
      t.string   :orrd
      t.string   :destination_type
      t.string   :destination
      t.integer  :status
      t.integer  :outward_reference_document
      t.jsonb    :outward_reference_value
      t.integer  :mode
      t.integer  :logistic_partner
      t.string   :vehicle_number
      t.string   :dispatch_document_number
      t.string   :handover_document
      t.jsonb    :cancelled_items
      
      t.timestamps
    end
  end
end
