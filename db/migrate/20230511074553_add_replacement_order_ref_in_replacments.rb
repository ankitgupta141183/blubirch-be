class AddReplacementOrderRefInReplacments < ActiveRecord::Migration[6.0]
  def change
    add_column :replacements, :replacement_order_id, :integer
  end
end
