class CreateRtvAlerts < ActiveRecord::Migration[6.0]
  def change
    create_table :rtv_alerts do |t|

      t.integer :alert_id
      t.string :recipient_email
      t.string :subject
      t.text :body
      t.string :attachment_file
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :rtv_alerts, :alert_id
  end
end
