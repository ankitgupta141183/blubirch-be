class AddIndexToDistributionCenter < ActiveRecord::Migration[6.0]
  def change
    add_index :liquidations, :distribution_center_id
  end
end
