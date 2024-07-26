class CreateAlertInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :alert_inventories do |t|
      t.references :inventory, index: true
      t.jsonb :details

      t.timestamps
    end
  end
end
