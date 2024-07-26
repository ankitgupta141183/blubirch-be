class CreateInventoryDocuments < ActiveRecord::Migration[6.0]
  def change
    create_table :inventory_documents do |t|
      t.integer :inventory_id
      t.integer :document_name_id
      t.string :reference_number
      t.string :attachment
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :inventory_documents, :inventory_id
  end
end