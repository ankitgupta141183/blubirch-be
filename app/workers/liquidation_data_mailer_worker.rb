class LiquidationDataMailerWorker

  include Sidekiq::Worker

  def perform(current_user_id, distribution_center_ids, liquidation_ids = nil)
    user = User.find_by_id(current_user_id)
    liquidations = Liquidation.where(distribution_center_id: distribution_center_ids, is_active: true, status: 'Competitive Bidding Price')
    liquidations = liquidations.where(id: liquidation_ids) if liquidation_ids.present?

    csv_file = CSV.generate do |csv|
      csv << ["Title", "Lot Name", "Site Location", "Tag Number", "Category L1", "Category L2", "Category L3", "Category L4", "Category L5", "Category L6", "Item Type", "Brand", "Model", "Sub-Model/ Variant",  "MRP (in INR)", "Quantity", "Physical",  "Functional Status", "Packaging status", "Accessories", "Grade", "Item Description", "Remarks", "Floor Price"]

      liquidations.each do |liquidation|
        categories = {}

        (1..6).each do |level|
          categories["category_l#{level}"] = liquidation.details["category_l#{level}"]
          categories["leaf_category"] = liquidation.details["category_l#{level}"] if liquidation.details["category_l#{level}"].present?
        end

        inventory = liquidation.inventory

        physical_status = inventory.details["processed_grading_result"]["Physical Condition"] rescue 'NA'
        functional_status = inventory.details["processed_grading_result"]["Functional"] rescue 'NA'
        packaging_status = inventory.details["processed_grading_result"]["Packaging"] rescue 'NA'
        accessories = inventory.details["processed_grading_result"]["Accessories"] rescue 'NA'

        model = inventory.details["Model"] rescue ''
        sub_model = inventory.details["Sub-Model/ Variant"] rescue ''

        csv << [liquidation.item_description, nil, liquidation.location, liquidation.tag_number, categories["category_l1"], categories["category_l2"], categories["category_l3"], categories["category_l4"], categories["category_l5"], categories["category_l6"], categories["leaf_category"], liquidation.details["brand"], model, sub_model, liquidation.try(:bench_mark_price), '1', physical_status, functional_status, packaging_status, accessories, liquidation.grade, liquidation.item_description, (liquidation.inventory.details['manual_remarks'].present? ? liquidation.inventory.details['manual_remarks'] : liquidation.inventory.remarks), "" ]
      end
    end

    amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)
    bucket = Rails.application.credentials.aws_bucket
    time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')
    file_name = "competitive_liquidations_#{time.parameterize.underscore}"
    obj = amazon_s3.bucket(bucket).object("uploads/competitive_downloaded_liquidations/#{file_name}.csv")
    obj.put(body: csv_file, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')
    url = obj.public_url

    VendorMailer.liquidation_data_email(url, user).deliver_now
  end
end
