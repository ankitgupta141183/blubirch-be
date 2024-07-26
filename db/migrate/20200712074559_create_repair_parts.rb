class CreateRepairParts < ActiveRecord::Migration[6.0]
  def change
    create_table :repair_parts do |t|

      t.string :name
      t.string :part_number
      t.float :price
      t.jsonb :details
      t.string :hsn_code
      t.boolean :is_active, default: true
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
