class CreateCapitalAssets < ActiveRecord::Migration[6.0]
  def change
    create_table :capital_assets do |t|
      t.string :assigned_to
      t.string :tag_number
      t.string :article_sku
      t.string :article_description
      t.string :assigned_disposition
      t.string :brand
      t.string :assigned_username
      t.string :aisle_location
      t.string :status

      t.integer :status_id
      t.integer :assignment_status
      t.integer :inventory_id
      t.integer :distribution_center_id
      t.integer :client_id
      t.integer :client_tag_number
      t.integer :client_category_id
      t.integer :assigned_user_id
      t.integer :disposition_assigned_by

      t.boolean :is_active

      t.jsonb :details

      t.timestamps
    end
  end
end
