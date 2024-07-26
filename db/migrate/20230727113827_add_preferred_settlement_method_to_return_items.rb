class AddPreferredSettlementMethodToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :preffered_settlement_method, :string
    add_column :return_items, :preffered_settlement_method_id, :integer
    add_index :return_items, :preffered_settlement_method_id
    add_index :return_items, :preffered_settlement_method
  end
end
