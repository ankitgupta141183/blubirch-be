class CreateRepairs < ActiveRecord::Migration[6.0]
  def change
    create_table :repairs do |t|
      
      t.integer :distribution_center_id
      t.integer :inventory_id
      t.integer :tag_number
      t.json :details
      t.boolean :approval_required, default: true
      t.integer :status_id
      t.boolean :is_active, default: true
      t.datetime :deleted_at
      
      t.timestamps
    end
  end
end
