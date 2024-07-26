class UpdateRestockCategory < ActiveRecord::Migration[6.0]
  def change
    Restock.update_all("category = (details ->> 'category_l3')")
  end
end
