class AddColumnToCoupanCode < ActiveRecord::Migration[6.0]
  def change
    add_column :coupan_codes, :deleted_at, :datetime
  end
end
