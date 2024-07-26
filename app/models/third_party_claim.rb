# frozen_string_literal: true

# id                           :integer
# claim_raised_date            :date              dd/mm/yyyy
# inventory_id                 :integer
# tag_number                   :string
# status                       :integer           [:pending, closed]
# vendor_code                       :string
# note_type                    :integer           [:credit, :debit]
# approval_reference_number    :string
# credit_debit_note_number     :string
# cost_type                    :integer           [:repair_cost, :write_off]
# claim_amount                 :float
# stage_name                   :integer           [:rtv, :discount, :insurance_claim, :debit_note_against_vendors, :repair_cost]

class ThirdPartyClaim < ApplicationRecord
  belongs_to :inventory

  enum status: { pending: 1, closed: 2 }, _prefix: true
  enum note_type: { credit: 1, debit: 2 }, _prefix: true
  enum cost_type: { repair_cost: 1, write_off: 2 }, _prefix: true
  enum stage_name: { rtv: 1, discount: 2, insurance_claim: 3, debit_note_against_vendors: 4, repair_cost: 5 }, _prefix: true
  enum tab_status: { recovery: 1, cost: 2, closed: 3 }, _prefix: true

  validates :claim_raised_date, :vendor_code, :claim_amount, presence: true
  validates :tag_number, presence: true
  validates :status, inclusion: { in: ThirdPartyClaim.statuses.keys }
  validates :note_type, inclusion: { in: ThirdPartyClaim.note_types.keys }, if: proc { !stage_name_repair_cost? }
  validates :cost_type, inclusion: { in: ThirdPartyClaim.cost_types.keys }, if: proc { stage_name_repair_cost? }
  validates :stage_name, inclusion: { in: ThirdPartyClaim.stage_names.keys }
  # validates_uniqueness_of :inventory_id, if: Proc.new { self.status_pending? }, scope: :tab_status

  # ? ThirdPartyClaim::SAMPLE_CLAIM_ATTR
  SAMPLE_CLAIM_ATTR = [].freeze

  # * Create 3pClaim Record
  # ^ claim_attributes = [{ inventory_id:, stage_name:, vendor_code:, note_type:, approval_reference_number:, cost_type:, claim_amount: , tab_status:}]
  # ? ThirdPartyClaim.create_thrid_party_claim(sample_attrs)
  def self.create_thrid_party_claim(claim_attributes)
    # & Initialize
    tpclaim_data = []

    # & Array data contains 3pClaim attributes
    claim_attributes.each_with_index do |data, _index|
      # & Getting inventory data
      inventory = Inventory.find_by(id: data[:inventory_id])
      raise CustomErrors, 'Invalid Item ID.' if inventory.blank?

      # & Assigning default attributes
      data[:claim_raised_date] = Date.current
      data[:tag_number] = inventory.tag_number
      data[:status] = :pending

      tpclaim_data << data
    end

    # & Bulk Import
    import_response = ThirdPartyClaim.import! tpclaim_data, validate: true, validate_uniqueness: true, track_validation_failures: true
  end
end
