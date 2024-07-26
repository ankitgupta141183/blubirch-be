class Tally::InwardPurchaseOrderService
  include Utils::Formatting

  #? Tally::InwardPurchaseOrderService.get_records(OrderManagementSystem.all)
  def self.get_records(data:)
    final_hash = { batch_number: data.first.batch_number, values_arr: [] }
    data.each do |oms|
      vendor_details = oms.vendor_details
      receiving_location_details = oms.receiving_location_details
      billing_details = oms.billing_location_details
      data_hash = {
        "subject": "details of #{oms.order_type.sub('_', ' ').upcase}",
        "po_number": oms.reason_reference_document_no,
        "pod_date": oms.rrd_creation_date.to_s(:p_date1),
        "status": oms.status,
        "remarks": oms.remarks,
        "vendor_address": self.vendor_address_details(vendor_details),
        "shipping_address": self.shipping_address_details(receiving_location_details),
        "billing_address": self.billing_address_details(billing_details),
        "vendor_gst_type": "",
        "vendor_gst_number": "",
        "customer_gst_type": "",
        "customer_gst_number": "",
        "items": []
      }

      oms.order_management_items.each do |item|
        data_hash[:items] << {
          "sku_code": item.sku_code,
          "sku_description": item.item_description,
          "quantity": item.quantity,
          "hsn_code": "",
          "unit_price": item.price,
          "total_price": item.total_price,
          "cgst_tax_percentage": "",
          "cgst_tax_amount": "",
          "tax_type": "",
          "igst_tax_percentage": "",
          "igst_tax_amount": "",
          "sgst_tax_percentage": "",
          "sgst_tax_amount": ""
        }
      end
      final_hash[:values_arr] << data_hash
    end
    final_hash
  end

  def self.vendor_address_details(vendor_details)
    {
      "vendor_name": vendor_details['vendor_name'],
      "vendor_code": vendor_details['vendor_code'],
      "vendor_contact_no": "",
      "vendor_address_1": "",
      "vendor_address_2": "",
      "vendor_address_3": "",
      "vendor_city": "",
      "vendor_state": "",
      "vendor_country": "",
      "vendor_pincode": ""
    }
  end

  def self.shipping_address_details(receiving_location_details)
    {
      "customer_name": receiving_location_details['name'],
      "customer_contact_no": "",
      "customer_address_1": "",
      "customer_address_2": "",
      "customer_address_3": "",
      "customer_city": receiving_location_details['city'],
      "customer_state": receiving_location_details['state'],
      "customer_country": receiving_location_details['country'],
      "customer_pincode": ""
    }
  end

  def self.billing_address_details(billing_details)
    {
      "customer_name": billing_details['name'],
      "customer_contact_no": "",
      "customer_address_1": "",
      "customer_address_2": "",
      "customer_address_3": "",
      "customer_city": billing_details['city'],
      "customer_state": billing_details['state'],
      "customer_country": billing_details['country'],
      "customer_pincode": ""
    }
  end

end