class AddColumnToEWasteHistory < ActiveRecord::Migration[6.0]
  def change
    add_column :e_waste_histories, :details, :jsonb
  end
end
