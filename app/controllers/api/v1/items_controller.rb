# frozen_string_literal: true

module Api
  module V1
    # item controller for item inwarding
    class ItemsController < ApplicationController
      include SkuCodeQuery
      include GenerateTagNumber

      before_action :validate_csv_file, only: :create_bulk_inwards_file_import

      def create_bulk_inwards_file_import
        flg, details = Item.import_inward_details_from_file(params[:file], current_user, params[:client_id])
        if flg.present?
          if details.present?
            render json: { message: 'PRD details imported successfully.', error_records: details }
          else
            respond_with_success('PRD details imported successfully.')
          end
        else
          respond_with_error("#{details}. Please Upload valid CSV File")
        end
      end

      # def create
      #   client = Client.first
      #   inward = Item.new(inward_parms.except('grade'))
      #   inward.prd_grade = inward_parms[:grade]
      #   lookup_key = LookupKey.find_by(name: 'INWARD_STATUSES', code: 'INWARD_STATUSES')
      #   lookup_value = LookupValue.find_by(lookup_key_id: lookup_key&.id, code: 'inward_statuses_pending_receipt', original_code: 'Pending Receipt')
      #   inward.status = lookup_value&.original_code
      #   inward.status_id = lookup_value&.id
      #   inward.user_id = user_id
      #   inward.client_id = client.id
      #   if inward.save
      #     respond_with_success('Record is created successfully')
      #   else
      #     respond_with_error(inward.errors.full_messages.join(','))
      #   end
      # end

      def consignment_inward
        box = Item.where(reverse_dispatch_document_number: params[:reverse_dispatch_document_number], location: params[:inward_location], logistics_partner_name: params[:reverse_logistic_partner])
        if box.blank?
          respond_with_error('Item is mapped to some other Return Processing Location')
        else
          consignment_detail = ConsignmentDetail.find_or_initialize_by(consignment_params)
          consignment_detail.user_id = user_id
          if consignment_detail.save
            respond_with_success('Details are created successfully')
          else
            respond_with_error(consignment_detail.errors.full_messages.join(','))
          end
        end
      end

      def box_inwards
        client = Client.first
        today = Time.zone.today
        req_params = params
        common_response('Please add at least 1 reverse_dispatch_document_number detail.', 422) and return if req_params[:reverse_dispatch_document_numbers].blank?

        lookup_key = LookupKey.find_by(code: 'BOX_STATUSES')
        lookup_values = lookup_key.lookup_values
        pend_box = lookup_values.find_by(code: 'box_statuses_pending_box_resolution')
        inward_box = lookup_values.find_by(code: 'box_statuses_box_inwarded')
        reverse_dispatch_document_numbers = params[:reverse_dispatch_document_numbers]
        reverse_dispatch_document_numbers = JSON.parse(reverse_dispatch_document_numbers, symbolize_names: true) if reverse_dispatch_document_numbers.is_a?(String)
        reverse_dispatch_document_numbers.each do |rddn_detail|
          rddn = rddn_detail[:rddn]
          rddn_detail[:box_details].each do |box_detail|
            box_number = box_detail[:box_number]
            box = Item.boxes.where(box_number: box_number, box_status: [nil, 'Box Inwarded']).first
            next if box&.box_status.present?

            inward_location = params[:inward_location]
            reverse_logistic_partner = params[:reverse_logistic_partner]
            if box.present?
              box_status = box.reverse_dispatch_document_number.to_s == rddn.to_s ? inward_box : pend_box
              attrs = { user_id: user_id, box_status_id: box_status&.id, box_status: box_status&.original_code, box_condition: box_detail[:box_status],
                        box_inwarded_date: today, location: inward_location, reverse_dispatch_document_number: rddn,
                        logistics_partner_name: reverse_logistic_partner, gate_pass_number: params[:gate_pass_number], po_number: params[:po_number],
                        invoice_number: params[:invoice_number], referance_document_number: params[:referance_document_number] }
              box.items.update_all(attrs)
              box.update(attrs)
            else
              box = Item.find_or_initialize_by(box_number: box_number, user_id: user_id, client_id: client&.id, location: inward_location,
                                               logistics_partner_name: reverse_logistic_partner, reverse_dispatch_document_number: rddn)
              box.update(box_status_id: pend_box&.id, box_status: pend_box&.original_code, box_inwarded_date: today, client_resolution: true, item_resolution: true)
            end
            box_images = box_detail[:box_images]
            next if box_images.blank?

            box_images.each do |img|
              BoxImage.create(attachment_file: img, box_number: box_number, client_id: client&.id, user_id: user_id)
            end
          end
          box_receipt_file = params[:box_receipt_file]
          if box_receipt_file.present?
            BoxReceiptAcknowledgement.create(user_id: user_id, reverse_dispatch_document_number: rddn,
                                             attachment_file: box_receipt_file)
          end
          damage_certificate = params[:damage_certificate]
          DamageCertificate.create(user_id: user_id, reverse_dispatch_document_number: rddn, attachment_file: damage_certificate) if damage_certificate.present?
        end

        common_response('Boxes are inwarded successfully')
      end

      def box_receipt_summary
        common_response('Please add referance_document_numbers', 422) if params[:reverse_dispatch_document_numbers].blank?
        data = fetch_box_summary # (params)
        render json: data.merge!({ message: 'Box condition Summary fetched successfully.' }), status: :ok
      end

      def item_attributes
        article_id = params[:article_id]
        respond_with_error('Please pass tag_id and sku_code to get attributes') and return if article_id.blank?

        box_id = params[:box_id]
        tag_id = params[:tag_id]
        qry = build_sku_code_query(article_id.downcase)
        qry += "box_number = '#{box_id}'" if box_id.present?
        qry += " AND tag_number = '#{tag_id}'" if tag_id.present?
        item = Item.where(qry).first
        if item.present?
          render json: { id: item.id, field_attributes: item.field_attributes }.merge({ message: 'Item attributes fetched successfully!' }), status: :ok
        else
          common_response('Item is not found by provided details', 422)
        end
      end

      def mismatch_update
        id = params[:id]
        item = Item.find_by(id: id)
        respond_with_error('Item is not found') and return if item.nil?

        if item.update(item_params)
          mismatch_st = params.dig(:item, :item_mismatch_status)
          if mismatch_st.to_s.downcase == 'yes'
            lookup_key = LookupKey.find_by(code: 'INWARD_STATUSES')
            lookup_value = lookup_key.lookup_values.where(code: 'inward_statuses_pending_item_resolution').first
            item.update(item_issue: 'Item Mismatch', status: lookup_value.original_code, status_id: lookup_value.id, confirmed_by: current_user.username)
          end
          common_response('Item status and attributes are update.')
        else
          common_response(item.errors.full_messages.join(','), status: 422)
        end
      end

      def pending_box_resolutions
        set_pagination_params(params)
        search = params[:search]
        locations = params[:locations]
        client_ids = params[:client_ids]
        qry = 'box_number in (?)', search if search.present?
        items = Item.boxes.where(box_status: 'Pending Box Resolution').where(qry) # .group_by(&:box_number).values.map{|a| a[0]}.compact.map(&:id)
        # items = Item.where(id: item_ids)
        items = items.where(location: locations) if locations.present?
        items = items.where(client_id: client_ids) if client_ids.present?
        items = items.page(@current_page).per(@per_page)
        render json: items, each_serializer: PendingBoxSerializer, meta: pagination_meta(items)
      end

      def box_conditions
        lookup_key = LookupKey.find_by(code: 'BOX_CONDITION')
        lookup_values = lookup_key.lookup_values
        msg = lookup_values.present? ? 'Box conditions fetched successfully' : 'No box conditions are found'
        common_response(msg, 200, 'box_conditions', lookup_values.map { |a| { id: a.id, original_code: a.original_code } })
      end

      def boxes
        boxes = current_user.items.inwarded_boxes_with_pending_items
        search = params[:search]
        boxes = boxes.where('items.box_number ilike ? ', "%#{search}%") if search.present?
        if boxes.blank?
          common_response('Boxes are not founds', 200, 'boxes', [])
        else
          common_response('Boxes are founds', 200, 'boxes', boxes.pluck(:box_number).uniq)
        end
      end

      def inwarded_items
        search = params[:search]
        items = Item.exclude_boxes.where(status: 'Inwarded', grade: nil)
        items = items.where('tag_number ilike ?', "%#{search}%") if search.present?
        common_response('No items are found for inwards') and return if items.blank?

        common_response('Items fetched successfully.', 200, 'items', items.select('box_number, sku_code AS article_id, tag_number, id'))
      end

      def item_inwards
        article_id = params[:article_id]
        tag_id = params[:tag_id]
        serial_number_1 = params[:serial_number_1]
        serial_number_2 = params[:serial_number_2]
        tag_item = Item.find_by(tag_number: tag_id)
        if tag_item.blank?
          create_tag_mismatch_item
          common_response('Tag id is mismatch and moved to Pending Item Resolution.', 422, 'error_messages', {
                            tag_id_mismatch: 'Tag id mismatch', sn_1_mismatch: nil, sn_2_mismatch: nil
                          }) and return
        end
        unless tag_item.read_attribute(:sku_code).to_s == article_id.to_s
          common_response("Tag id is associated with #{tag_item.read_attribute(:sku_code).to_s} Article, Can't proceed.", 422, 'error_messages', {
                            tag_id_mismatch: 'Tag id mismatch', sn_1_mismatch: nil, sn_2_mismatch: nil
                          }) and return
        end
        if tag_item.status == 'Pending Item Resolution'
          common_response('Item can not be inwarded as item in Pending Item Resolution', 422, 'error_messages', {
                            tag_id_mismatch: nil, sn_1_mismatch: nil, sn_2_mismatch: nil
                          }) and return
        end

        items = Item.exclude_boxes.where(build_sku_code_query(article_id.downcase))
        item = items.find_by(tag_number: tag_id)
        inward_types = fetch_inward_type(article_id)

        if item.blank?
          common_response('Item is not found by provided tag_number and article id.', 422, 'error_messages', {
                            tag_id_mismatch: 'Tag id is not available', sn_1_mismatch: nil, sn_2_mismatch: nil
                          }) and return
        end

        item_status = item&.status
        item_grade = item.grade
        item_grn_number = item.grn_number
        if item_status.present? && item_status == 'Inwarded' && item_grade.present? && item_grn_number.present?
          common_response('The item you want to inward is already inwarded', 422, 'error_messages', {}) and return
        end

        tag_id_mismatch = 'Tag id is not available.' unless item.tag_number.to_s.downcase == tag_id.to_s.downcase
        sn_1_mismatch = 'Serial number 1 is mismatch' unless item.serial_number_1.to_s.downcase == serial_number_1.to_s.downcase
        sn_2_mismatch = 'Serial number 2 is mismatch' unless item.serial_number_2.to_s.downcase == serial_number_2.to_s.downcase

        if tag_id_mismatch.present? || sn_1_mismatch.present? || sn_2_mismatch.present?
          err = { tag_id: tag_id_mismatch, serial_number_1: sn_1_mismatch, serial_number_2: sn_2_mismatch }
          common_response('Serial Number not matching with PRD', 422, 'error_messages', err) and return
        end
        if inward_types['grading_after_inwards'] && item_status == 'Inwarded' && item_grn_number.present? && item_grade.blank?
          common_response('Item already inwarded and Pending for grading.', 422, 'error_messages', err) and return
        end

        lookup_key = LookupKey.find_by(code: 'INWARD_STATUSES')
        inward_status = lookup_key.lookup_values.where(code: 'inward_statuses_inwarded').first
        if item.update(received_sku: article_id, status_id: inward_status.id, status: inward_status.original_code, item_inwarded_date: Time.now)
          common_response('Item is inwareded successfully', 200, 'error_messages', {})
        else
          common_response(item.errors.full_messages.join(','), 422, 'error_messages', {})
        end
      end

      def grading_before_inwards
        tag_id = params[:tag_id]
        current_time = Time.zone.now.to_s
        username = current_user.username
        generated_tag_numbers = []
        ActiveRecord::Base.transaction do
          params[:article_ids].each do |artical_id|
            if tag_id.present? && params.key?(:is_single_inwarding).blank?
              item = Item.where(tag_number: tag_id, sku_code: artical_id).first
              respond_with_error('Priovided tag id is not available.') and return if item.blank?

              if item.grade.blank?
                item.grade = params[:grade]
                item.details.merge!({ 'inward_user_name' => username, 'inward_grading_time' => current_time })
                item.save
                respond_with_success('Items are graded.') and return if item.client_resolution.present?

                respond_with_success('Items are graded, and move to return request claim approval bucket') and return
              elsif item.grn_number.blank?
                respond_with_success('Item is already Graded and Pending for GRN.')
              else
                respond_with_error('Item is already Graded and GRN is also updated')
              end
            else
              tag_numbers = Item.distinct.pluck(:tag_number).compact
              lookup_key = LookupKey.find_by(code: 'INWARD_STATUSES')
              # TODO: remove this hardcoded value after getting confirmation from product team
              distribution_center = current_user.distribution_centers.first
              client_sku_master = ClientSkuMaster.find_by(code: artical_id)
              client_category = client_sku_master&.client_category
              client_id = Client.first.id
              pending_grn_status = lookup_key.lookup_values.where(code: 'inward_statuses_pending_grn').first
              params[:grade_with_quantity].each do |quantity_grade|
                quantities = quantity_grade[:quantity].to_i
                grade = quantity_grade[:grade]
                tag_id = nil
                quantities.times.each do |_q|
                  number_is_valid = false
                  until number_is_valid
                    tag_id = generate_uniq_tag_number
                    number_is_valid = validate_uniqueness(true, tag_numbers, tag_id)
                  end
                  generated_tag_numbers << tag_id
                  item = current_user.items.new(tag_number: tag_id, sku_code: artical_id, sku_description: client_sku_master.sku_description, asp: 0.01,
                                                  details: { 'inward_user_name' => username, 'inward_grading_time' => current_time },
                                                  quantity: 1, grade: grade, box_number: params[:box_number], location: distribution_center.name, is_serialized_item: true,
                                                  status_id: pending_grn_status.id, status: pending_grn_status.original_code, client_id: client_id, client_category_name: client_category.name, client_category_id: client_category.id)
                  item.save
                end
              end
            end
          end
        end
        common_response('Tag numbers are created and grade are set.', 200, :tag_numbers, generated_tag_numbers)
      end

      def pending_item_resolutions
        set_pagination_params(params)
        search = params[:search]
        locations = params[:locations]
        item_issues = params[:item_issues]
        client_ids = params[:client_ids]
        qry = ['tag_number in (?)', search] if search.present?
        items = Item.exclude_boxes.where(status: 'Pending Item Resolution').where(qry)
        items = items.where(location: locations) if locations.present?
        items = items.where(item_issue: item_issues) if item_issues.present?
        items = items.where(client_id: client_ids) if client_ids.present?
        items = items.page(@current_page).per(@per_page)
        render json: items, each_serializer: PendingItemSerializer, meta: pagination_meta(items)
      end

      def accept
        items = Item.where(id: params[:ids])
        box_accept = params[:accept_type].to_s == 'Box'
        items = Item.where(box_number: items.pluck(:box_number).compact, box_status: 'Pending Box Resolution') if box_accept
        if items.present?
          lookup_key = LookupKey.where(code: 'INWARD_STATUSES').first
          lookup_value = lookup_key.lookup_values.find_by(code: 'inward_statuses_pending_item_inwarding')
          box_lookup_key = LookupKey.find_by(code: 'BOX_STATUSES')
          inward_box = box_lookup_key.lookup_values.find_by(code: 'box_statuses_box_inwarded')
          if box_accept
            items.update_all(box_status: inward_box&.original_code, box_status_id: inward_box&.id)
          else
            items.update_all(status: lookup_value&.original_code, status_id: lookup_value&.id)
          end
        end
        respond_with_success('All items of provided ids are now accepted.')
      end

      def send_to_customer
        items = Item.where(id: params[:ids])
        if items.present?
          lookup_key = LookupKey.where(code: 'INWARD_STATUSES').first
          lookup_value = lookup_key.lookup_values.find_by(code: 'inward_statuses_send_to_customer')
          items.update_all(status: lookup_value&.original_code, status_id: lookup_value&.id)
        end
        respond_with_success('All items of provided ids are now send to customer.')
      end

      def send_to_consignor
        items = Item.where(id: params[:ids])
        if items.present?
          lookup_key = LookupKey.where(code: 'INWARD_STATUSES').first
          lookup_value = lookup_key.lookup_values.find_by(code: 'inward_statuses_send_to_consignor')
          items.update_all(status: lookup_value&.original_code, status_id: lookup_value&.id)
        end
        respond_with_success('All items of provided ids are now send to consignor.')
      end

      def rejected
        items = Item.where(id: params[:ids])
        if items.present?

          if params[:from_page] == 'Box'
            lookup_key = LookupKey.where(code: 'BOX_STATUSES').first
            lookup_value = lookup_key.lookup_values.find_by(code: 'box_statuses_box_rejected')
            items.update_all(box_status: lookup_value&.original_code, box_status_id: lookup_value&.id, current_status: 'Pending Dispatch')
          else
            lookup_key = LookupKey.where(code: 'INWARD_STATUSES').first
            lookup_value = lookup_key.lookup_values.find_by(code: 'inward_statuses_item_rejected')
            items.update_all(status: lookup_value&.original_code, status_id: lookup_value&.id, current_status: 'Pending Dispatch')
          end
        end
        respond_with_success('All items of provided ids are now Rejected.')
      end

      def write_off
        items = Item.where(id: params[:ids])
        if items.present?
          lookup_key = LookupKey.where(code: 'INWARD_STATUSES').first
          lookup_value = lookup_key.lookup_values.find_by(code: 'inward_statuses_write_off')
          items.update_all(status: lookup_value&.original_code, status_id: lookup_value&.id)
        end
        respond_with_success('All items of provided ids are now write off.')
      end

      def update_grn
        tag_numbers = params[:tag_ids]
        items = Item.where(tag_number: tag_numbers)
        user_name = current_user.username
        if items.present?
          items.each do |item|
            item.details.merge!('grn_submitted_user_name' => user_name, 'grn_received_user_name' => user_name)
            item.update(grn_number: params[:grn_number], grn_submitted_time: Time.zone.now.to_s)
          end
          respond_with_success('Grn updated.')
        else
          respond_with_error('Item not found by provided tag ids')
        end
      end

      def rejected_boxes
        set_pagination_params(params)
        search = params[:search]
        customer_detail = params[:customer_detail]
        current_status = params[:current_status]
        qry = ['box_number in (?) OR tag_number in (?)', search, search] if search.present?
        items = Item.where("status = 'Item Rejected' OR box_status = 'Box Rejected'").where(receipt_date: nil).where(qry)
        items = items.where(logistics_partner_name: customer_detail) if customer_detail.present?
        items = items.where(current_status: current_status) if current_status.present?
        items = items.page(@current_page).per(@per_page)
        render json: items, each_serializer: RejectedBoxItemSerializer, meta: pagination_meta(items)
      end

      def update_pending_dispatch
        ids = params[:ids]
        respond_with_error('Please provide proper id.') and return if ids.blank?

        item = Item.where(id: ids)
        if item.present?
          item.update_all(document_number: params[:dispatch_document_number], reverse_dispatch_document_number: params[:reference_document_number], dispatch_date: params[:dispatch_date],
                          logistics_partner_name: params[:logistic_partner], current_status: 'Pending Receipt')
          respond_with_success('Item fields are updated')
        else
          respond_with_error('item is not found from provided id.')
        end
      end

      def update_pending_receipt
        ids = params[:ids]
        respond_with_error('Please provide proper id.') and return if ids.blank?

        item = Item.where(id: ids)
        if item.present?
          item.update_all(receipt_date: params[:receipt_date], pod: params[:pod], current_status: 'Pending Receipt')
          respond_with_success('Item is in pending receipt')
        else
          respond_with_error('item is not found from provided id.')
        end
      end

      def item_details
        ids = params[:ids]
        respond_with_error('Please provide proper id.') and return if ids.blank?

        set_pagination_params(params)
        items = Item.where(id: ids).page(@current_page).per(@per_page)
        if items.present?
          render json: items, each_serializer: ItemPendingDispatchSerializer, meta: pagination_meta(items)
        else
          respond_with_error('item is not found from provided id.')
        end
      end

      def article_inward_type
        article_id = params[:article_id]
        common_response('Please provide proper article_id.', 422, 'inward_types', {}) and return if article_id.blank?

        item = Item.exclude_boxes.where(build_sku_code_query(article_id.downcase)).where.not(status: 'Pending Item Resolution', brand: nil, client_category_name: nil).last
        common_response('Item is not found by provided Article id.', 422, 'inward_types', {}) and return if item.blank?

        # API for rule engine starts
        url = "#{Rails.application.credentials.rule_engine_url}/api/v1/inwarding_rules/inward_types"
        serializable_resource = { category: item.client_category_name, brand: item.brand, sku: item.read_attribute(:sku_code) }.as_json
        response = RestClient::Request.execute(method: :get, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
        # API for rule engine ends
        if response.present?
          parsed_response = JSON.parse(response)
          # render json: parsed_response
          common_response('Inward type lists', 200, 'inward_types', parsed_response)
        else
          common_response('Inward types not able to find.', 200, 'inward_types', {})
        end
      end

      def grading_questions
        article_id = params[:article_id]
        common_response('Please provide proper article_id.', 422) and return if article_id.blank?

        # item = Item.find_by(sku_code: params[:article_id])
        item = Item.where(build_sku_code_query(article_id.downcase)).first
        common_response('Item is not found by provided Article id.', 422) and return if item.blank?

        # API for rule engine starts
        url = "#{Rails.application.credentials.rule_engine_url}/api/v1/grades/questions"
        serializable_resource = { client_name: 'reliance', category: item.client_category_name, grade_type: 'Warehouse' }.as_json
        response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
        # API for rule engine ends
        if response.present?
          common_response('Question Fetched.', 200, 'questions', JSON.parse(response))
        else
          common_response('Failed to get grading questions.', 422)
        end
      end

      def compute_grade
        article_id = params[:article_id]
        item = Item.where(build_sku_code_query(article_id.downcase)).first
        common_response('Item is not found by provided Article id.', 422, 'grade_details', []) and return if item.blank?

        response = fetch_grade(item, params[:final_grading_result])
        if response.present?
          parsed_response = JSON.parse(response)
          final_grade = parsed_response['grade']
          grading_error = parsed_response['grading_error']
          processed_grading_result = parsed_response['processed_grading_result']
          common_response('Grade fetched successfully', 200, 'grade_details', { final_grade: final_grade, grading_error: grading_error, processed_grading_result: processed_grading_result })
        else
          common_response('Failed to get grading details.', 422, 'grade_details', [])
        end
      end

      def submit_grades
        item = Item.where(build_sku_code_query(params[:article_id].downcase)).where(tag_number: params[:tag_id]).first
        common_response('Item is not found by provided Article id.', 422) and return if item.blank?

        response = fetch_grade(item, final_grading_result = params[:final_grading_result])
        if response.present?
          parsed_response = JSON.parse(response)
          final_grade = parsed_response['grade']
          # grading_error = parsed_response['grading_error']
          processed_grading_result = parsed_response['processed_grading_result']
          functional = processed_grading_result['Functional Condition']
          physical = processed_grading_result['Physical Condition']
          packaging = processed_grading_result['Packaging Condition']
          accessories = processed_grading_result['Accessories']
          purchase_price = item.purchase_price
          if final_grade.present?
            url = "#{Rails.application.credentials.rule_engine_url}/api/v1/dispositions"
            answers = [{ 'test_type' => 'Functional Condition', 'output' => (functional != 'NA' ? functional : 'All') },
                       { 'test_type' => 'Physical Condition', 'output' => (physical != 'NA' ? physical : 'All') },
                       { 'test_type' => 'Packaging Condition', 'output' => (packaging != 'NA' ? packaging : 'All') },
                       { 'test_type' => 'Accessories', 'output' => (accessories != 'NA' ? accessories : 'All') },
                       { 'test_type' => 'Days from Installation', 'output' => begin
                         item.installation_date.strftime('%Y-%m-%d')
                       rescue StandardError
                         'All'
                       end },
                       { 'test_type' => 'Purchase Price', 'output' => (!purchase_price.nil? ? purchase_price : 'All') },
                       { 'test_type' => 'Days from Purchase Invoice', 'output' => begin
                         item.purchase_invoice_date.strftime('%Y-%m-%d')
                       rescue StandardError
                         'All'
                       end },
                       { 'test_type' => 'Days from Sales Invoice', 'output' => begin
                         item.sales_invoice_date.strftime('%Y-%m-%d')
                       rescue StandardError
                         'All'
                       end }]

            serializable_resource = { client_name: 'reliance', category: item.client_category_name, brand: item.brand, answers: answers }.as_json
            response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
            common_response('Dispostion not found', 422) and return if response.blank?

            username = current_user.username
            item_details = item.details
            response_str = response.to_s
            is_client_resolution = item.client_resolution.present?
            item.grade = final_grade
            item.tested_by = username
            item.disposition = response_str
            item_details['final_grading_result'] = final_grading_result.as_json
            item_details['processed_grading_result'] = processed_grading_result
            item_details['inward_user_name'] = username
            item_details['inward_grading_time'] = Time.zone.now.to_s
            item.details = item_details
            item.create_dispostions(response_str) if is_client_resolution
            item.save!
          end
          if is_client_resolution
            common_response('Grading is done for provided article id and dispostion bucket is assigned')
          else
            common_response('Grading is done, Item move to pending return request approval bucket')
          end
        else
          common_response('Failed to get grading questions.', 422)
        end
      end

      def item_mismatch_claim
        set_pagination_params(params)
        search = params[:search]
        usernames = params[:usernames]
        article_ids = params[:article_ids]
        qry = ['tag_number in (?)', search] if search.present?
        items = Item.no_item_mismatch_claim.where(item_issue: ['Tag id Mismatch', 'Item Mismatch']).where(qry)
        items = items.where('confirmed_by IN (?) ', usernames) if usernames.present?
        items = items.where('sku_code in (?) OR changed_sku_code in (?)', article_ids, article_ids) if article_ids.present?
        items = items.page(@current_page).per(@per_page)
        render json: items, each_serializer: ItemMismatchClaimSerializer, meta: pagination_meta(items)
      end

      def item_grade_mismatch_claim
        set_pagination_params(params)
        search = params[:search]
        qry = ['tag_number in (?)', search] if search.present?
        prd_grades = params[:prd_grades]
        received_grades = params[:received_grades]
        usernames = params[:usernames]
        article_ids = params[:article_ids]
        filter_qry = {}
        filter_qry.merge!({ prd_grade: prd_grades }) if prd_grades.present?
        filter_qry.merge!({ grade: received_grades }) if received_grades.present?
        items = Item.no_grade_mismatch_claim.where.not(grade: nil, prd_grade: nil).where('prd_grade <> grade').where(qry).where(filter_qry)
        items = items.where('tested_by IN (?) ', usernames) if usernames.present?
        items = items.where('sku_code in (?) OR changed_sku_code in (?)', article_ids, article_ids) if article_ids.present?
        items = items.page(@current_page).per(@per_page)
        render json: items, each_serializer: ItemGradeMismatchClaimSerializer, meta: pagination_meta(items)
      end

      def logistic_partner_claims
        set_pagination_params(params)
        search = params[:search]
        rddns = params[:rddns]
        tag_ids = params[:tag_ids]
        receipt_dates = params[:receipt_dates]
        qry = ['tag_number in (?)', search] if search.present?
        filter_qry = {}
        filter_qry.merge!({ reverse_dispatch_document_number: rddns }) if rddns.present?
        filter_qry.merge!({ tag_number: tag_ids }) if tag_ids.present?
        filter_qry.merge!({ box_inwarded_date: receipt_dates }) if receipt_dates.present?

        items = Item.exclude_boxes.no_logistic_claim.where(box_status: 'Box Inwarded', box_condition: ['Minor Damaged', 'Major Damaged']).where(qry).where(filter_qry).page(@current_page).per(@per_page)
        render json: items, each_serializer: ItemLogisticClaimSerializer, meta: pagination_meta(items)
      end

      def no_claims
        items = Item.where(id: params[:ids])
        claim_name = params[:claim_name]
        if items.present?
          items.update_all(current_status: 'No Claims')
          items.each do |item|
            item.details["#{claim_name}_no_claim"] = true
            item.save
          end
          respond_with_success('Selected items updated with no claims.')
        else
          respond_with_error('No Items are found by provided ids')
        end
      end

      def raise_debit_notes
        items = Item.where(id: params[:ids])
        vendor_code = params[:vendor_code]
        claim_amount = params[:claim_amount]
        claim_name = params[:claim_name] # logistic or grade_mismatch or item_mismatch
        respond_with_error('No Items are found by provided ids') and return if items.blank?
        respond_with_error('Please add claim amount and vendor') and return if vendor_code.blank? || claim_amount.blank?

        hash = { vendor_code: vendor_code, note_type: :debit, cost_type: :write_off, claim_amount: claim_amount, stage_name: :debit_note_against_vendors, tab_status: :recovery }
        vendor = VendorMaster.find_by(vendor_code: vendor_code)
        respond_with_error('Vendor is not available by provided call') and return if vendor.blank?

        items.each do |item|
          item.details["#{claim_name}_debit_note_request"] = { 'vendor_code' => vendor_code, 'name' => vendor&.vendor_name, 'amount' => claim_amount }
          item.create_dispostions('3pClaim', hash)
          item.current_status = '3p Claims'
          item.save!
        end
        respond_with_success('Items are moved to 3p Claims.')
      rescue StandardError => e
        respond_with_error(e.message)
      end

      def upload_damage_certificate
        file = params[:file]
        respond_with_error('Please upload file.') and return if file.blank?

        item = Item.where(id: params[:id]).first
        respond_with_error('No Items found by provided by id.') and return if item.blank?

        damage_certificate = DamageCertificate.find_or_initialize_by(attachmentable: item, client_id: Client.first.id, user_id: user_id,
                                                                     reverse_dispatch_document_number: item.reverse_dispatch_document_number).tap { |dc| dc.attachment_file = file }

        if save_damage_certificate(damage_certificate)
          respond_with_success('Damage Certificates uploaded successfully.')
        else
          respond_with_error(build_error_message(damage_certificate))
        end
      end

      def pending_return_requests
        set_pagination_params(params)
        search = params[:search]
        article_ids = params[:article_ids]
        grades = params[:grades]
        qry = ['tag_number in (?)', search] if search.present?
        sku_qry = 'changed_sku_code in (?) OR sku_code in (?)', article_ids, article_ids if article_ids.present?
        filter_qry = { grade: grades } if grades.present?
        items = Item.where(box_status: 'Box Inwarded', client_resolution: false).where.not(grade: nil).where(qry).where(filter_qry).where(sku_qry).page(@current_page).per(@per_page)
        render json: items, each_serializer: ItemReturnRequestClaimSerializer, meta: pagination_meta(items)
      end

      def approve_return_request
        items = Item.where(id: params[:ids])
        respond_with_error('No Items found by provided by id(s).') and return if items.blank?

        items.each do |item|
          item.update(client_resolution: true)
        end
        respond_with_success('Selected Item(s) are approved and moved to respective buckets')
      end

      def reject_return_request
        items = Item.where(id: params[:ids])
        respond_with_error('No Items found by provided by id(s).') and return if items.blank?

        # TODO, as Return to Customer bucket is not implemented, so once completed will move item to that buckets
        # items.each do |item|
        #   item.create_dispostions("")
        # end
        respond_with_success('Selected Item(s) are Rejected and move to Return to Customer bucket.')
      end

      def pending_item_inwarding
        tag_number = params[:tag_number]
        qry = "tag_number ilike '%#{tag_number}%'" if tag_number.present?
        items = Item.exclude_boxes.where(client_id: Client.first.id, status: 'Pending Item Inwarding').where(qry)
        render json: items, each_serializer: PendingItemInwardingSerializer, meta: pagination_meta(items)
      end

      private

      # overriding controllers method as it will be easy to modify
      def common_permissions
        %i[index create_bulk_inwards_file_import create consignment_inward box_inwards box_receipt_summary pending_box_resolutions boxes item_inwards
           grading_before_inwards pending_item_resolutions accept send_to_customer send_to_consignor update_grn write_off rejected rejected_boxes update_pending_dispatch
           update_pending_receipt item_details item_attributes mismatch_update box_conditions inwarded_items article_inward_type grading_questions compute_grade submit_grades
           item_mismatch_claim item_grade_mismatch_claim logistic_partner_claims no_claims raise_debit_notes upload_damage_certificate pending_return_requests
           approve_return_request reject_return_request pending_item_inwarding]
      end

      def permissions
        {
          superadmin: {
            "api/v1/items": common_permissions
          },
          central_admin: {
            "api/v1/items": common_permissions
          },
          site_admin: {
            "api/v1/items": common_permissions
          },
          default_user: {
            "api/v1/items": common_permissions
          },
          inwarder: {
            "api/v1/items": %i[consignment_inward box_inwards box_receipt_summary boxes item_inwards grading_before_inwards update_grn item_attributes mismatch_update box_conditions
                               article_inward_type grading_questions compute_grade submit_grades pending_item_inwarding]
          },
          grader: {
            "api/v1/items": %i[grading_before_inwards inwarded_items article_inward_type grading_questions compute_grade submit_grades pending_item_inwarding]
          }
        }
      end

      def validate_csv_file
        file = params[:file]
        msg = nil
        validated = false
        if file.blank?
          msg = 'Please upload CSV file.'
        elsif file.content_type.exclude?('csv')
          msg = 'File format must be csv File. Please upload csv file.'
        else
          csv_data = CSV.read(file.path, headers: true, encoding: 'iso-8859-1:utf-8')
          headers = csv_data.headers
          missing_headers = Item::CSV_HEADERS - headers
          if missing_headers.present?
            msg = "File must contain headers like #{missing_headers.join(',')}"
          else
            validated = true
          end
        end
        respond_with_error(msg) and return if validated.blank?
      end

      def fetch_inward_type(sku_code)
        item = Item.where(build_sku_code_query(sku_code.downcase)).where.not(status: 'Pending Item Resolution', brand: nil, client_category_name: nil).last
        # API for rule engine starts
        url =  "#{Rails.application.credentials.rule_engine_url}/api/v1/inwarding_rules/inward_types"
        serializable_resource = { category: item.client_category_name, brand: item.brand, sku: item.read_attribute(:sku_code) }.as_json
        response = RestClient::Request.execute(method: :get, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
        JSON.parse(response)
      end

      def fetch_box_summary
        data = { boc_condition_summary: [], box_count_summary: [] }
        items = Item.boxes
        params[:reverse_dispatch_document_numbers].each do |rddn|
          rddn_box_details = rddn[:box_details]
          reverse_dispatch_document_numbers = rddn[:rddn]
          total_accepted = 0
          rddn_box_details.each do |box_detail|
            box_number = box_detail[:box_number]
            box = items.where(box_number: box_number).first
            matchig_status = box.present? && box.reverse_dispatch_document_number.to_s == reverse_dispatch_document_numbers.to_s ? 'Matching' : 'Not Matching'
            is_matched = matchig_status == 'Matching'
            total_accepted += 1 if is_matched
            data[:boc_condition_summary] << { dispatch_document_number: reverse_dispatch_document_numbers,
                                              box_id: box_number,
                                              box_condition: box_detail[:box_status],
                                              matchig_status: matchig_status,
                                              decision: is_matched ? 'Accept' : 'Reject' }
          end
          all_boxes = items.where(reverse_dispatch_document_number: reverse_dispatch_document_numbers)
          box_numbers = all_boxes.pluck(:box_number)
          data[:box_count_summary] << {
            dispatch_document_number: reverse_dispatch_document_numbers,
            total_boxes: box_numbers.compact.uniq.reject(&:empty?).count,
            total_received_boxes: rddn_box_details.count,
            total_accepted_boxes: total_accepted
          }
        end
        data
      end

      def fetch_data(items)
        data = { boc_condition_summary: [], box_count_summary: [] }
        params[:dispatch_document_numbers].each do |ddn|
          selected_items = items.where(reverse_dispatch_document_number: ddn)
          consignment_detail = ConsignmentDetail.where(reverse_dispatch_document_number: ddn)
          hash = {
            dispatch_document_number: ddn, total_boxes: consignment_detail.count, total_received_boxes: selected_items.where(status: 'Inwarded').count
          }
          data[:box_count_summary] << hash
        end

        items.each do |item|
          hash = {
            dispatch_document_number: item.reverse_dispatch_document_number,
            box_id: item.box_number,
            box_condition: item.box_condition,
            matchig_status: item.status == 'Pending Box Resolution' ? 'Not Matching' : 'Matching'
          }
          data[:boc_condition_summary] << hash
        end
        data
      end

      def inward_parms
        params.require(:inward).permit(Item::CSV_HEADERS.map(&:to_sym).push(:grade, :sales_invoice_date, :installation_date, :purchase_invoice_date, :purchase_price, category_node: {},
                                                                                                                                                                      field_attributes: {}))
      end

      def consignment_params
        params.permit(:inward_location, :reverse_logistic_partner, :gate_pass_number,
                      :po_number, :invoice_number, :invoice_date, :supplier, :referance_document_number,
                      :reverse_dispatch_document_number, :total_boxes, :client_id)
      end

      def item_params
        params.require(:item).permit(:item_mismatch_status, field_attributes: {})
      end

      def fetch_grade(item, final_grading_result)
        url = "#{Rails.application.credentials.rule_engine_url}/api/v1/grades/compute_grade"
        serializable_resource = { client_name: 'reliance', category: item.client_category_name, grade_type: 'Warehouse', final_grading_result: final_grading_result }.as_json
        RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
      end

      def save_damage_certificate(damage_certificate)
        if damage_certificate.save
          true
        else
          damage_certificate.new_record?
          false
        end
      end

      def build_error_message(damage_certificate)
        if damage_certificate.new_record?
          'File is already uploaded for the selected item'
        else
          damage_certificate.errors.full_messages.join('')
        end
      end

      def create_tag_mismatch_item
        lookup_key = LookupKey.find_by(code: 'INWARD_STATUSES')
        lookup_value = lookup_key.lookup_values.where(code: 'inward_statuses_pending_item_resolution').first
        box = Item.boxes.find_by(box_number: params[:box_number])
        item = Item.new(box_number: box&.box_number, parent_id: box&.id, client_id: Client.first.id, tag_number: params[:tag_id], sku_code: params[:article_id], serial_number_1: params[:serial_number_1], serial_number_2: params[:serial_number_2],
                        status: lookup_value&.original_code, status_id: lookup_value&.id, item_issue: 'Tag id Mismatch', received_sku: params[:article_id], location: box&.location, confirmed_by: current_user.username, user_id: current_user.id)
        item.save(validate: false)
      end

      def user_id
        @user_id ||= current_user.id
      end
    end
  end
end
