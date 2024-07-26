class AddIndexOnItemsField < ActiveRecord::Migration[6.0]
  def change
    add_index :items, :reverse_dispatch_document_number
    add_index :items, :box_number
    add_index :items, :tag_number
    add_index :items, :sku_code
    add_index :items, :parent_id
  end
end
