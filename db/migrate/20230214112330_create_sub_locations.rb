class CreateSubLocations < ActiveRecord::Migration[6.0]
  def change
    create_table :sub_locations do |t|
      t.integer  :distribution_center_id
      t.string   :name
      t.string   :code
      t.integer  :location_type
      t.jsonb    :category
      t.jsonb    :brand
      t.jsonb    :grade
      t.jsonb    :supplier
      t.jsonb    :disposition
      t.jsonb    :request_reason
      t.integer  :sequence
      t.time     :from_time
      t.time     :to_time

      t.timestamps
    end
  end
end
