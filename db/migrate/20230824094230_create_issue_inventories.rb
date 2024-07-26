class CreateIssueInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :issue_inventories do |t|
      t.integer :inventory_id
      t.string :tag_number
      t.string :request_id
      t.references :physical_inspection, null: false, foreign_key: true
      t.references :distribution_center, null: false, foreign_key: true
      t.string :location
      t.integer :inventory_status
      t.integer :status

      t.timestamps
    end
  end
end
