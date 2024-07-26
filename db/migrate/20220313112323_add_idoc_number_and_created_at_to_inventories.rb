class AddIdocNumberAndCreatedAtToInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :idoc_number, :string
    add_column :gate_passes, :idoc_created_at, :datetime
    add_index :gate_passes, :idoc_created_at
  end
end
