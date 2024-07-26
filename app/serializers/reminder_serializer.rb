class ReminderSerializer < ActiveModel::Serializer
	belongs_to :client_category
	belongs_to :client_sku_master
	belongs_to :customer_return_reason

  attributes :id, :status, :client_category_id, :customer_return_reason_id, :sku_master_id, :details, :approval_required, :deleted_at, :created_at, :updated_at

  def status
    LookupValue.where(id: object.status_id).last rescue nil
  end


end
