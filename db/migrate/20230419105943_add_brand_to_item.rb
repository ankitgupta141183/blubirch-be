class AddBrandToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :brand, :string
  end
end
