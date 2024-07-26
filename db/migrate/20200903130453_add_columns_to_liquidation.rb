class AddColumnsToLiquidation < ActiveRecord::Migration[6.0]
  def change
    add_column :liquidations, :client_id, :integer
    add_column :liquidations, :client_tag_number, :string
    add_column :liquidations, :serial_number, :string
    add_column :liquidations, :serial_number_2, :string
    add_column :liquidations, :toat_number, :string
    add_column :liquidations, :item_price, :float
    add_column :liquidations, :aisle_location, :string
  end
end
