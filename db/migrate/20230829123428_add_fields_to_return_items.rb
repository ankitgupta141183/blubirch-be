class AddFieldsToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :suggested_pickup_date, :date
    add_column :return_items, :actual_pickup_date, :date
    add_column :return_items, :logistic_partner, :string
    add_column :return_items, :dispatch_document_number, :string
    add_column :return_items, :boxes_to_pickup, :integer
    add_column :return_items, :actual_boxes_picked, :integer
    add_column :return_items, :delivery_location_id, :integer
  end
end
