class CreateThirdPartyClaims < ActiveRecord::Migration[6.0]
  #! id                           :integer
  #! claim_raised_date            :date              dd/mm/yyyy
  #! inventory_id                 :integer           
  #! tag_number                   :string
  #! status                       :integer           [:pending, closed]
  #! vendor                       :string              
  #! note_type                    :integer           [:credit, :debit]
  #! approval_reference_number    :string
  #! credit_debit_note_number     :string                 
  #! cost_type                    :integer           [:repair_cost, :write_off]
  #! claim_amount                 :float           
  #! stage_name                   :integer           [:rtv, :discount, :insurance_claim, :debit_note_against_vendors, :repair_cost]
  def change
    create_table :third_party_claims do |t|
      t.date :claim_raised_date
      t.references :inventory
      t.string :tag_number
      t.integer :status
      t.string :vendor
      t.integer :note_type
      t.string :approval_reference_number
      t.string :credit_debit_note_number
      t.integer :cost_type
      t.float :claim_amount
      t.integer :stage_name
      t.timestamps
    end
  end
end