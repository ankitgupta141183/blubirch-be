class CreateSellerCategories < ActiveRecord::Migration[6.0]
  def change
    create_table :seller_categories do |t|
      t.string :name
      t.jsonb :details
      t.references :client_category

      t.timestamps
    end
  end
end
