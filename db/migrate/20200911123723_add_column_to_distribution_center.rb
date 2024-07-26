class AddColumnToDistributionCenter < ActiveRecord::Migration[6.0]
  def change
    add_column :distribution_centers, :code, :string
  end
end
