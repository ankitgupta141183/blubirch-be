class AiFakeService

  def self.call_request(client_sku_master, return_inventory)
    payload_data, images_data, errors = self.build_json(client_sku_master.images.first, return_inventory.id, return_inventory.headers_data["data"])
    raise errors.join(',') and return if payload_data['Image-path'].blank? && errors.present?
    #"Authorization" => StringEncryptDecryptService.encode(Rails.application.credentials.ai_auth_string)
    headers = {"Content-Type" => "application/json" }
    return_inventory.update!(
      images: images_data,
      payload: {
        "url": 'https://qa-docker.blubirch.com:3205/fake_verification',
        "payload": payload_data,
        "headers": {"Content-Type" => "application/json"}
      }
    )
    response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.fake_ai_url, :payload => payload_data.to_json, headers: headers) #^ TODO: Url need to add in cred
    return "Data sent to AI", errors.join(',')
  end

  private

  def self.build_json(images_hash, return_inventory_id, headers_data)
    final_json = { "File-id" => return_inventory_id,"Image-path" => [], "final-prediction": "", "prediction-score": "" }
    images_data = []
    amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)
    bucket = Rails.application.credentials.aws_bucket
    bucket_url = amazon_s3.bucket(bucket).url
    errors = []
    headers_data.each do |question, return_image_url|
      side = ReturnInventory.question_map_to_side(question)
      errors << "Side not found for the question -> #{question}" if side.blank?
      next if side.blank?
      original_image_url = images_hash[side]
      errors << "Original Image url is not present for the question -> #{question}" if original_image_url.blank?
      errors << "Return Image url is not present for the question -> #{question}" if return_image_url.blank?

      next if original_image_url.blank? || return_image_url.blank?
      
      original_img_path = original_image_url.gsub("#{bucket_url}/","")
      original_img_name = File.basename(open(original_image_url), ".png")

      return_img_path = return_image_url.gsub("#{bucket_url}/","")
      return_img_name = File.basename(open(return_image_url), ".png")

      images_data << {
        side => {
          "Original" => original_image_url,
          "Return" => return_image_url
        }
      }

      sub_payload_json = {
        "View-name" => side.to_s&.capitalize,
        "Image" =>[
           {
              "File_Path" => original_img_path,
              "File_Name" => original_img_name,
              "Tag" =>"Original"
           },
           {
              "File_Path" => return_img_path,
              "File_Name" => return_img_name,
              "Tag" =>"Return"
           }
        ]
      }
      final_json['Image-path'] << sub_payload_json
    end
    
    [final_json, images_data, errors]
  end
end