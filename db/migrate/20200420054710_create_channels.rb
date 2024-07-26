class CreateChannels < ActiveRecord::Migration[6.0]
  def change
    create_table :channels do |t|
      t.integer :distribution_center_id
      t.string :name
      t.text :cost_formula
      t.text :revenue_formula
      t.text :recovery_formula
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :channels, :distribution_center_id
  end
end

