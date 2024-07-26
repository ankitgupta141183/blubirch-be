class AddTimelineTypeToSubLocations < ActiveRecord::Migration[6.0]
  def change
    add_column :sub_locations, :timeline_type, :integer
    add_column :sub_locations, :absolute_time, :time
    add_column :sub_locations, :relative_time, :integer
    remove_column :sub_locations, :from_time
    remove_column :sub_locations, :to_time
    
    add_column :distribution_centers, :is_sorted, :boolean, default: false
    
    add_column :request_items, :raised_against, :string
    add_column :request_items, :debit_amount, :float
  end
end
