class AddColumnToReplacement < ActiveRecord::Migration[6.0]
  def change
    add_column :replacements, :disposition_remark, :text
  end
end
