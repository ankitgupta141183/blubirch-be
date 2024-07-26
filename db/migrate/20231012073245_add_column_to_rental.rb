class AddColumnToRental < ActiveRecord::Migration[6.0]
  def change
    add_column :rentals, :rental_reserve_id, :string
    add_column :rentals, :buyer_code, :string
  end
end
