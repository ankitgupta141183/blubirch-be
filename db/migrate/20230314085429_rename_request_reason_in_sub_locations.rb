class RenameRequestReasonInSubLocations < ActiveRecord::Migration[6.0]
  def change
    rename_column :sub_locations, :request_reason, :return_reason
    
    add_column :put_requests, :disposition, :string
  end
end
