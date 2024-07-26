class CreateLookupKeys < ActiveRecord::Migration[6.0]
  def change
    create_table :lookup_keys do |t|
      t.string :name
      t.string :code
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
