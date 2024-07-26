class CreateQcConfigurations < ActiveRecord::Migration[6.0]
  def change
    create_table :qc_configurations do |t|
      t.integer :sample_percentage
      t.integer :distribution_center_id
      t.timestamps
    end

    add_index :qc_configurations, :distribution_center_id
    
  end
end
