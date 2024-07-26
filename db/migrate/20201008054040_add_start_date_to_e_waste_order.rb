class AddStartDateToEWasteOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :e_waste_orders, :start_date, :datetime
  end
end
