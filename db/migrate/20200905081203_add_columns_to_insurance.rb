class AddColumnsToInsurance < ActiveRecord::Migration[6.0]
  def change
    add_column :insurances, :client_id, :integer
    add_column :insurances, :client_tag_number, :string
    add_column :insurances, :serial_number, :string
    add_column :insurances, :toat_number, :string
    add_column :insurances, :item_price, :float
    add_column :insurances, :serial_number_2, :string
  end
end
