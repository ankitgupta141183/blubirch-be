class CreateRequestItems < ActiveRecord::Migration[6.0]
  def change
    create_table :request_items do |t|
      t.integer   :put_request_id
      t.integer   :inventory_id
      t.string    :box_no
      t.integer   :item_type
      t.integer   :from_sub_location_id
      t.integer   :to_sub_location_id
      t.integer   :status
      t.integer   :sequence

      t.timestamps
    end
  end
end
