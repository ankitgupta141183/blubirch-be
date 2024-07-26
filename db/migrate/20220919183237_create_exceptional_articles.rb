class CreateExceptionalArticles < ActiveRecord::Migration[6.0]
  def change
    create_table :exceptional_articles do |t|
      t.string :sku_code 
      t.string :scan_id
      t.integer :serial_number_length
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :exceptional_articles, :sku_code
  end
end
