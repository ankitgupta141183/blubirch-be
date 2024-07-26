class CreateRentals < ActiveRecord::Migration[6.0]
  def change
    create_table :rentals do |t|
      t.string :tag_number
      t.string :article_sku
      t.string :article_description
      t.string :assigned_disposition
      t.string :brand
      t.string :buyer_name
      t.string :lease_payment_frequency
      t.string :aisle_location
      t.string :status

      t.integer :status_id
      t.integer :inventory_id
      t.integer :distribution_center_id
      t.integer :client_id
      t.integer :client_tag_number
      t.integer :client_category_id
      t.integer :assigned_user_id
      t.integer :disposition_assigned_by
      t.integer :notice_period_days
      t.integer :lease_amount
      t.integer :security_deposit
      t.integer :unit_price
      t.integer :quantity

      t.boolean :is_active

      t.jsonb :details

      t.datetime :lease_start_date
      t.datetime :lease_end_date

      t.timestamps
    end
  end
end
