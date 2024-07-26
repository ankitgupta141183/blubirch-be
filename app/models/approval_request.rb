class ApprovalRequest < ApplicationRecord
  belongs_to :approvable, polymorphic: true
  belongs_to :approval_configuration, optional: true
  belongs_to :user, optional: true

  after_commit :sync_to_rule_engine

  enum status: { sent: 1, approved: 2, rejected: 3, not_approved: 4, not_rejected: 5 }, _prefix: true
  enum rule_field: { amount: 1 }, _prefix: true
  enum approval_rule_type: { insurance: 1, repair: 2, liquidation: 3, brand_call_log: 4, liquidation_payment_approval: 5 }, _prefix: true

  validates_uniqueness_of :approvable_id, scope: [:approvable_type, :status], if: Proc.new { self.status_sent? && self.approvable_type != "LiquidationOrder" }

  before_save :process_request, if: Proc.new { self.approved_on_changed? || self.rejected_on_changed? }

  #& Create approval request based on the dedicated appoval configuration
  def self.create_approval_request(object:, request_type:, request_amount:, details:)
    
    #& Getting approval configuration record
    #approval_config = ApprovalConfiguration.get_record(object_name: object.class.name)
    #if approval_config.present? 
    #end

    #& Creating Approval Request
    ApprovalRequest.create!({
      approvable: object,      
      status: :sent,
      rule_field: :amount,
      approval_rule_type: request_type.to_sym,
      value: request_amount,
      details: details
    })
  end
  

  private

  def process_request
    case self.approvable_type

    #& Bucket names
    when "Insurance"
      object = self.approvable
      #& If request is approved
      if self.approved_on.present?
        approve_action(object)
      else #& if request is rejected
        reject_action(object)
      end

    when "Liquidation"
      object = self.approvable
      #& If request is approved
      if self.approved_on.present?
        approve_action(object)
      else #& if request is rejected
        reject_action(object)
      end

    when "BrandCallLog"
      object = self.approvable
      if self.approved_on.present?
        approve_action(object)
      else
        begin
          object.update!(assigned_disposition: nil, assigner_id: nil)
          self.status = :rejected
        rescue => exc
          self.status = :not_rejected
          self.exception_response = "Error: #{exc} || Backtrace: #{exc.backtrace.to_s.truncate(1000)}"
        end
      end

    when "LiquidationOrder"
      object = self.approvable
      if self.approved_on.present?
        begin
          object.approve_winner_details
          self.status = :approved
        rescue => exc
          self.status = :not_approved
          self.exception_response = "Error: #{exc} || Backtrace: #{exc.backtrace.to_s.truncate(1000)}"
        end
      else
        begin
          object.reject_winner_details
          self.status = :rejected
        rescue => exc
          self.status = :not_rejected
          self.exception_response = "Error: #{exc} || Backtrace: #{exc.backtrace.to_s.truncate(1000)}"
        end
      end
    end

  end

  def approve_action(object)
    begin
      next_disposition = object.assigned_disposition
      object.set_disposition(next_disposition)
      self.status = :approved
    rescue => exc
      self.status = :not_approved
      self.exception_response = "Error: #{exc} || Backtrace: #{exc.backtrace.to_s.truncate(1000)}"
    end
  end

  def reject_action(object)
    begin
      object.update!(assigned_disposition: nil, assigned_id: nil)
      self.status = :rejected
    rescue => exc
      self.status = :not_rejected
      self.exception_response = "Error: #{exc} || Backtrace: #{exc.backtrace.to_s.truncate(1000)}"
    end
  end

  def sync_to_rule_engine
    Notification::ApprovalRequestService.new(self).call if self.approved_on.blank? && self.rejected_on.blank?
  end
end
