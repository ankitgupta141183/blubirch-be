class AddAspToMarkdown < ActiveRecord::Migration[6.0]
  def change
    add_column :markdowns, :asp, :float
  end
end
