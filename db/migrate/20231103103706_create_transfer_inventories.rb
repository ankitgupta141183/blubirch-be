class CreateTransferInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :transfer_inventories do |t|
      t.references :inventoryable, polymorphic: true, null: false, index: { name: 'index_ti_on_inventoryable' }
      t.references :transfer_order
      t.references :vendor_master
      t.string :article_id
      t.string :article_description
      t.string :tag_number
      t.jsonb :details
      t.references :client_category
      t.references :sub_location
      t.references :distribution_center
      t.integer :receving_location_id
      t.string :remarks
      t.date :transfer_date
      t.string :status
      t.integer :status_id
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
