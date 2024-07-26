class CreateScanInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :scan_inventories do |t|
      t.references :physical_inspection, null: false, foreign_key: true
      t.references :distribution_center, null: false, foreign_key: true
      t.string :request_id
      t.string :tag_number

      t.timestamps
    end
  end
end
