class Tally::OutwardTransferOrderService
  include Utils::Formatting

  def self.get_records(data:)
    values_arr = data.map do |oms|
      {
        to_number: oms.reason_reference_document_no,
        to_date: oms.rrd_creation_date,
        status: oms.status,
        total_amount: oms.amount,
        subject: oms.details["subject"],
        shipment_date: oms.details["shipment_date"],
        validity_date: oms.details["validity_date"],
        customer_id: oms.details["customer_id"],
        contact_name: oms.details["contact_name"],
        to_account_name: oms.details["so_account_name"],
        customer_gst_type: oms.details["customer_gst_type"],
        customer_gst_number: oms.details["customer_gst_number"],
        place_of_supply: oms.details["place_of_supply"],
        discount: oms.details["discount"],
        discount_type: oms.details["discount_type"],
        shipping_charge: oms.details["shipping_charge"],
        po_number: '',
        billing_address: oms.billing_location_details.as_json(only: [
          "billing_name",
          "billing_contact_no",
          "billing_address_1",
          "billing_address_2",
          "billing_address_3",
          "billing_city",
          "billing_state",
          "billing_country",
          "billing_pincode"
        ]),
        shipping_address: oms.shipping_location_details.as_json(only: [
          "shipping_name",
          "shipping_contact_no",
          "shipping_address_1",
          "shipping_address_2",
          "shipping_address_3",
          "shipping_city",
          "shipping_state",
          "shipping_country",
          "shipping_pincode"
        ]),
        items: oms.order_management_items.select(
          'sku_code',
          'item_description AS sku_description',
          'quantity',
          'price AS unit_price',
          'total_price',
          "details ->> 'warehouse_id' AS warehouse_id",
          "details ->> 'hsn_code' AS hsn_code",
          "details ->> 'warehouse_name' AS warehouse_name",
          "details ->> 'cgst_tax_percentage' AS cgst_tax_percentage",
          "details ->> 'cgst_tax_amount' AS cgst_tax_amount",
          "details ->> 'tax_type' AS tax_type",
          "details ->> 'igst_tax_percentage' AS igst_tax_percentage",
          "details ->> 'igst_tax_amount' AS igst_tax_amount",
          "details ->> 'sgst_tax_percentage' AS sgst_tax_percentage",
          "details ->> 'sgst_tax_amount' AS sgst_tax_amount"
        ).as_json(except: [:id])
      }
    end
    { batch_number: data.first.batch_number, values_arr: values_arr}
  end
end
