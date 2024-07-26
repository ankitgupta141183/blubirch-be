class AddCoulmnResolutionDate < ActiveRecord::Migration[6.0]
  def change
    add_column :insurances, :resolution_date, :datetime
    add_column :vendor_returns, :resolution_date, :datetime
    add_column :repairs, :resolution_date, :datetime
  end
end
