class AddIrrdNumberToItems < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :irrd_number, :string
    add_column :items, :ird_number, :string
    add_column :items, :return_sub_request_id, :string
  end
end
