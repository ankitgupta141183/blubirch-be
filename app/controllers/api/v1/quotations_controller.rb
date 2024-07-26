class Api::V1::QuotationsController < ApplicationController

	def lot_information
    link = VendorQuotationLink.find_by_token(params['token'])
    if link.present?
      vendor_master = link.vendor_master
      liquidation_order = link.liquidation_order
      
      if liquidation_order.present?
        if link.expired?
          render json: {message: "Link has been Expired", status: 302}
        else
          render json: {lot_id: liquidation_order.id, lot_name: liquidation_order.lot_name, count: "#{liquidation_order.quantity} Items",
                        city: vendor_master.vendor_city, lot_amount: liquidation_order.order_amount,
                        end_date: liquidation_order.end_date_with_localtime.strftime("%d/%b/%Y - %I:%M %p"), images: liquidation_order.lot_image_urls, status: 200

          }
        end
      end
    else
      render json: {message: "Link has been Expired", status: 302}
    end
  end

  def create_quotation
    link = VendorQuotationLink.find_by_token(params['token'])
    quotation = Quotation.new(vendor_master_id: link.vendor_master_id, liquidation_order_id: link.liquidation_order_id, expected_price: params['amount'])

    if link.expired?
      render json: {message: "Link has been Expired", status: 302}
    elsif quotation.save 
      render json: {message: "Successfully created", status: 200}
    else
      render json: {message: "Error in creation", status: 302}
    end
  end

  def download_manifesto

    liquidation_order = LiquidationOrder.includes(liquidations: [:inventory]).where("id = ?", params["id"]).first
    liquidation_inventories = liquidation_order.liquidations
    
    file_csv = CSV.generate do |csv|
      
      csv << ["Title Lot Name", "City", "Tag Number", "Inventory ID", "Category L1", "Category L2", "Category L3", "Item Type", "Brand", "Model", "Sub-Model/ Variant",  "MRP (in INR)", "MEP", "Quantity",  "Functional Status", "Packaging status", "Grade", "Item Description", "Remarks"]

      liquidation_inventories.each do |liquidation_inventory|
        
        city = DistributionCenter.find(liquidation_inventory.distribution_center_id).city.original_code rescue ""
        if liquidation_inventory.details["own_label"] == true
          item_type = "OL"          
        else
          item_type = "Non OL"
        end
        category_l1 = liquidation_inventory.details["category_l1"] rescue ""
        category_l2 = liquidation_inventory.details["category_l2"] rescue ""
        category_l3 = liquidation_inventory.details["category_l3"] rescue ""
        functional_status = liquidation_inventory.details["processed_grading_result"]["Functional"] rescue ""
        packaging_status = liquidation_inventory.details["processed_grading_result"]["Packaging"] rescue ""

        csv << [liquidation_order.lot_name, city, liquidation_inventory.tag_number, liquidation_inventory.inventory_id, category_l1, category_l2, category_l3, item_type, liquidation_inventory.details["brand"], "", "", liquidation_inventory.try(:mrp), liquidation_inventory.try(:floor_price), "1", functional_status, packaging_status, liquidation_inventory.grade, liquidation_inventory.item_description, (liquidation_inventory.inventory.details['manual_remarks'].present? ? liquidation_inventory.inventory.details['manual_remarks'] : liquidation_inventory.inventory.remarks) ]
      end
    end

    amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

    bucket = Rails.application.credentials.aws_bucket

    time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

    file_name = "manifesto_#{time.parameterize.underscore}"

    obj = amazon_s3.bucket(bucket).object("uploads/manifestos/#{file_name}.csv")

    obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

    url = obj.public_url

    puts url
    
    render json: {url: url}
  end


end
