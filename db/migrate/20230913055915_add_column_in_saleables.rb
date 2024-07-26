class AddColumnInSaleables < ActiveRecord::Migration[6.0]
  def change
    add_column :saleables, :location, :string
    add_reference :saleables, :distribution_center
  end
end
