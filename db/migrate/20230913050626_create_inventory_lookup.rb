class CreateInventoryLookup < ActiveRecord::Migration[6.0]
  def change
    create_table :inventory_lookups do |t|
      t.string  :name
      t.string  :original_name
      t.boolean :is_active,    default: false
      t.boolean :is_mandatory, default: false

      t.timestamps
    end
  end
end
