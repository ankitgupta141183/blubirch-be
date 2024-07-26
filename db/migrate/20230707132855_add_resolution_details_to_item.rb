class AddResolutionDetailsToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :client_resolution, :boolean
    add_column :items, :item_resolution, :boolean
    add_column :items, :asp, :float
  end
end
