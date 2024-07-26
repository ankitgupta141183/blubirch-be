class WarehouseOrder < ApplicationRecord
  acts_as_paranoid
  belongs_to :orderable, polymorphic: true
  has_many :warehouse_order_items
  belongs_to :distribution_center
  has_many :warehouse_order_documents, as: :attachable

  before_save :set_destination_type, if: Proc.new { self.destination_type.blank? }
  
  DESTINATION_TYPES = {"LiquidationOrder" => "Buyer", "VendorReturnOrder" => "Vendor", "RepairOrder" => "Service Center", "MarkdownOrder" => "Location", "TransferOrder" => "Location", "ReplacementOrder" => "Vendor" }

  before_save do
    true if self.vendor_name.present? || self.vendor_code.blank?
    if self.vendor_code.present? && self.vendor_name.blank?
      self.vendor_name = VendorMaster.find_by_vendor_code(self.vendor_code)&.vendor_name
    end
  end

  def update_bucket_status(orderable_type)

    case orderable_type
    when "LiquidationOrder"
      liquidations = self.orderable.liquidations
      liquidations.each do |record|
        record.update(is_active: false)
      end

    when "RedeployOrder"
      redeploys = self.orderable.redeploys
      redeploys.each do |record|
        record.update(is_active: false)
      end

    when "EWasteOrder"
      e_wastes = self.orderable.e_wastes
      e_wastes.each do |record|
        record.update(is_active: false)
      end
    
    when "MarkdownOrder"
      markdowns = self.orderable.markdowns
      markdowns.each do |record|
        record.update(is_active: false)
      end

    when "InsuranceOrder"
      insurances = self.orderable.insurances
      insurances.each do |record|
        record.update(is_active: false)
      end
    
    when "TransferOrder"
      restocks = self.orderable.restocks
      restocks.each do |record|
        record.update(is_active: false)
      end

    when "RepairOrder"
      repair = self.orderable.repair
      repair.update!(is_active: false)
    
    end
  end

  def self.update_toat_numbers
    dispositions = LookupKey.where(code: "WAREHOUSE_DISPOSITION").last.lookup_values.pluck(:original_code)
    dispositions.delete('Restock')
    dispositions.each do |bucket|

      if bucket == "Brand Call-Log"
        VendorReturn.all.each do |vr|
          vr.toat_number = vr.inventory.toat_number if vr.toat_number.blank?
          vr.save
          if vr.vendor_return_order.present?
            order = vr.vendor_return_order
            woi = order.warehouse_orders.last.warehouse_order_items.where(tag_number: vr.tag_number) rescue []
            woi.each do |i|
              i.update_attributes(toat_number: vr.toat_number) if i.toat_number.blank?
            end
          end
        end

      elsif bucket == "E-Waste"
        EWaste.all.each do |ew|
          ew.toat_number = ew.inventory.toat_number if ew.toat_number.blank?
          ew.save
          if ew.e_waste_order.present?
            order = ew.e_waste_order
            woi = order.warehouse_orders.last.warehouse_order_items.where(tag_number: ew.tag_number) rescue []
            woi.each do |i|
              i.update_attributes(toat_number: ew.toat_number) if i.toat_number.blank?
            end
          end
        end
      else

        bucket.split(' ').join('').constantize.all.each do |record|
          record.toat_number = record.inventory.toat_number if record.toat_number.blank?
          record.save
        end

        if bucket == "Liquidation"
          bucket.constantize.all.each do |l|
            if l.liquidation_order.present?
              order = l.liquidation_order
              woi = order.warehouse_orders.last.warehouse_order_items.where(tag_number: l.tag_number) rescue []
              woi.each do |i|
                i.update_attributes(toat_number: l.toat_number) if i.toat_number.blank?
              end
            end
          end
        end

        if bucket == "Pending Transfer Out"
          bucket.constantize.all.each do |l|
            if l.markdown_order.present?
              order = l.markdown_order
              woi = order.warehouse_orders.last.warehouse_order_items.where(tag_number: l.tag_number) rescue []
              woi.each do |i|
                i.update_attributes(toat_number: l.toat_number) if i.toat_number.blank?
              end
            end
          end
        end

        if bucket == "Insurance"

          bucket.constantize.all.each do |l|
            if l.insurance_order.present?
              order = l.insurance_order
              woi = order.warehouse_orders.last.warehouse_order_items.where(tag_number: l.tag_number) rescue []
              woi.each do |i|
                i.update_attributes(toat_number: l.toat_number) if i.toat_number.blank?
              end
            end
          end
        end

        if bucket == "Redeploy"

          bucket.constantize.all.each do |l|
            if l.redeploy_order.present?
              order = l.redeploy_order
              woi = order.warehouse_orders.last.warehouse_order_items.where(tag_number: l.tag_number) rescue []
              woi.each do |i|
                i.update_attributes(toat_number: l.toat_number) if i.toat_number.blank?
              end
            end
          end
        end

        if bucket == "Restock"

          bucket.constantize.all.each do |l|
            if l.restock.present?
              order = l.restock
              woi = order.warehouse_orders.last.warehouse_order_items.where(tag_number: l.tag_number) rescue []
              woi.each do |i|
                i.update_attributes(toat_number: l.toat_number) if i.toat_number.blank?
              end
            end
          end
        end

        if bucket == "Repair"

          bucket.constantize.all.each do |l|
            if l.repair_order.present?
              order = l.repair_order
              woi = order.warehouse_orders.last.warehouse_order_items.where(tag_number: l.tag_number) rescue []
              woi.each do |i|
                i.update_attributes(toat_number: l.toat_number) if i.toat_number.blank?
              end
            end
          end
        end
      end
    end
  end

  def set_destination_type
    self.destination_type = get_destination_type
    self.destination = "#{self.destination_type[0]}-#{rand(10000..50000)}"
    self.reference_number = "OR-#{self.orderable_type}-#{SecureRandom.hex(6)}" if self.reference_number.blank?
  end
  
  def get_destination_type
    destination_type = DESTINATION_TYPES[orderable_type]
    destination_type ||= "Location"
    destination_type
  end

end
