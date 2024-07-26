class CreateCapitalAssetHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :capital_asset_histories do |t|
      t.integer :capital_asset_id
      t.integer :status_id
      t.jsonb :details
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :capital_asset_histories, :capital_asset_id
  end
end
