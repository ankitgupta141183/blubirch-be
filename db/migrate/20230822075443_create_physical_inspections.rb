class CreatePhysicalInspections < ActiveRecord::Migration[6.0]
  def change
    create_table :physical_inspections do |t|
      t.references :distribution_center, null: false, foreign_key: true
      t.string :request_id
      t.integer :inventory_type
      t.text :brands
      t.text :category_ids
      t.text :article_ids
      t.text :assignee_ids
      t.jsonb :assignees_hash
      t.text :dispositions
      t.integer :status

      t.timestamps
    end
  end
end
