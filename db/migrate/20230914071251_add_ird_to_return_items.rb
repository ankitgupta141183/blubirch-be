class AddIrdToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :ird_number, :string
    
    add_column :items, :return_item_id, :integer
  end
end
