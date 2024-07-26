class AddColumnsToReaminingBuckets < ActiveRecord::Migration[6.0]
  def change
    add_column :redeploys, :is_active, :boolean, default: true
    add_column :e_wastes, :is_active, :boolean, default: true
    add_column :markdowns, :is_active, :boolean, default: true
    add_column :liquidations, :is_active, :boolean, default: true
  end
end
