class Api::V1::Warehouse::ThirdPartyClaimSerializer < ActiveModel::Serializer
  
  #& Attributes with conditions
  attributes :id, :tag_number, :formatted_date, :vendor_name, :approval_reference_number, :claim_amount, :tab_name

  attribute :formatted_stage_name, if: Proc.new { !object.stage_name_repair_cost? || object.status_closed? }
  attribute :formatted_note_type, if: Proc.new { !object.stage_name_repair_cost? || object.status_closed? }

  attribute :formatted_cost_type, if: Proc.new { object.stage_name_repair_cost? || object.status_closed? }

  attribute :credit_debit_note_number, if: Proc.new { object.status_closed? }

  #& Instance Methods
  def formatted_date
    object.claim_raised_date.strftime("%d/%m/%Y")
  end

  def formatted_stage_name
    object.stage_name.humanize
  end

  def formatted_note_type
    object.note_type&.humanize
  end

  def formatted_cost_type
    object.cost_type&.humanize
  end

  def vendor_name
    vendor_master = VendorMaster.find_by_vendor_code(object.vendor_code)
    vendor_master&.vendor_name
  end

  def tab_name
    object.stage_name_repair_cost? ? 'Cost' : 'Recovery'
  end

  #& Conditions for displaying the attributes
  def from_recovery_tab?
    !object.stage_name_repair_cost? 
  end

  def from_cost_tab?
    object.stage_name_repair_cost?
  end

  def from_closed_tab?
    object.status_closed?
  end
end