class CreateInsurers < ActiveRecord::Migration[6.0]
  def change
    create_table :insurers do |t|
      t.string   :name
      t.jsonb    :insurance_claim_type
      t.integer  :timeline
      t.integer  :insurance_value_parameter
      t.integer  :claim_raising_method
      t.float    :insurance_cover
      t.float    :excess
      t.jsonb    :required_documents

      t.timestamps
    end
  end
end
