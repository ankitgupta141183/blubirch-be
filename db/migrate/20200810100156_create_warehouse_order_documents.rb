class CreateWarehouseOrderDocuments < ActiveRecord::Migration[6.0]
  def change
    create_table :warehouse_order_documents do |t|
      t.integer :attachable_id
      t.string :attachable_type
      t.string :document_name
      t.integer :document_name_id
      t.string :reference_number
      t.string :attachment
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
