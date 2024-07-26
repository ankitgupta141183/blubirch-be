class ItemPendingDispatchSerializer < ActiveModel::Serializer
  attributes :id, :tag_number, :box_number, :receipt_date, :pod, :document_number, :reverse_dispatch_document_number, :dispatch_date, :logistics_partner_name
end
