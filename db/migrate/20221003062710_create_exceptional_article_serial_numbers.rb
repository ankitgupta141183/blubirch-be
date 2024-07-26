class CreateExceptionalArticleSerialNumbers < ActiveRecord::Migration[6.0]
  def change
    create_table :exceptional_article_serial_numbers do |t|
      t.string :sku_code 
      t.integer :serial_number_length
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :exceptional_article_serial_numbers, :sku_code
  end
end
