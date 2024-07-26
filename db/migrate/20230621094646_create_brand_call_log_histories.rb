class CreateBrandCallLogHistories < ActiveRecord::Migration[6.0]
  def change
    create_table   :brand_call_log_histories do |t|
      t.references :brand_call_log
      t.integer    :status_id
      t.jsonb      :details
      t.datetime   :deleted_at
      
      t.timestamps
    end
  end
end
