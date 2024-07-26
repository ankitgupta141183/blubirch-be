class AddDispositionToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :disposition, :string 
    add_column :return_items, :disposition_id, :integer
    add_index :return_items, :disposition_id
    add_index :return_items, :disposition
  end
end
