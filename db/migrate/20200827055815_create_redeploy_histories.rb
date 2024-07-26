class CreateRedeployHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :redeploy_histories do |t|
    	t.references :redeploy
    	t.integer :status_id
    	t.jsonb :details
    	t.datetime :deleted_at
      t.timestamps
    end
  end
end