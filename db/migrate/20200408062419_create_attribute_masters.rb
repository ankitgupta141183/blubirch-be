class CreateAttributeMasters < ActiveRecord::Migration[6.0]
  def change
    create_table :attribute_masters do |t|
      t.string :attr_type
      t.string :reason
      t.string :attr_label
      t.string :field_type
      t.text :options
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
