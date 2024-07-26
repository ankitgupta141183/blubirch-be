class AddColumnInPutRequest < ActiveRecord::Migration[6.0]
  def change
    add_column :put_requests, :is_dispatch_item, :boolean, :default => false
  end
end
