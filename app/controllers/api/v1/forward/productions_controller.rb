# frozen_string_literal: true

module Api
  module V1
    module Forward
      class ProductionsController < ApplicationController
        before_action :get_productions, only: %i[update_production_inventory set_disposition]
        before_action :get_article, only: %i[bom_details item_details update_item knit_items]
        before_action :get_production, only: %i[item_details update_item knit_items]

        # web apis
        def index
          set_pagination_params(params)
          filter_productions

          @productions = @productions.page(@current_page).per(@per_page)
          render_collection(@productions, Api::V1::Forward::ProductionSerializer)
        end
        
        def filters_data
          article_type_key = LookupKey.find_by(code: 'ARTICLE_TYPES')
          article_types = article_type_key.lookup_values.as_json(only: %i[id original_code])
          
          uom_key = LookupKey.find_by(code: 'UOM_CODES')
          uoms = uom_key.lookup_values.as_json(only: %i[id original_code])
          
          render json: { article_types: article_types, uoms: uoms }
        end

        def update_production_inventory
          ActiveRecord::Base.transaction do
            production_inventory_status = LookupValue.find_by(code: 'production_status_production_inventory')
            
            items_count = @productions.count
            @productions.each do |production|
              production.update(status_id: production_inventory_status.id, status: production_inventory_status.original_code)
              production.update_inventory_status(production_inventory_status, current_user.id)
            end
            render json: { message: "#{items_count} item(s) moved to Production Inventory" }
          end
        end

        def get_dispositions
          lookup_key = LookupKey.find_by(code: 'FORWARD_DISPOSITION')
          dispositions = lookup_key.lookup_values.where(original_code: %w[Saleable Usage Rental Demo Replacement]).as_json(only: %i[id original_code])
          render json: { dispositions: dispositions }
        end

        def set_disposition
          ActiveRecord::Base.transaction do
            disposition = LookupValue.find_by(id: params[:disposition_id])
            raise CustomErrors, "Disposition can't be blank" if disposition.blank?
            raise CustomErrors, 'Selected disposition is under development!' if %w[Usage].include? disposition.original_code

            items_count = @productions.count
            @productions.each do |production|
              production.set_disposition(disposition.original_code, current_user)
            end

            render json: { message: "#{items_count} item(s) moved to #{disposition.original_code}" }
          end
        end

        # mobile apis
        def get_finished_articles
          articles = ClientSkuMaster.joins(:bom_articles).distinct
          articles = articles.where("client_sku_masters.code ILIKE ?", "%#{params[:search]}%") if params[:search].present?
          articles = articles.limit(100).as_json(only: %i[id code sku_description])
          
          render json: { articles: articles }
        end
        
        def bom_details
          ActiveRecord::Base.transaction do
            data = @parent_article.as_json(only: %i[id code sku_description production_cost uom])
            data[:bom] = @parent_article.bom_mappings.as_json(only: %i[sku_code quantity uom])
            
            production = create_production
            data[:production_id] = production.id

            render json: { data: data }
          end
        end
        
        def item_details
          raise 'Invalid Details' and return if params[:tag_number].blank? && params[:sku_code].blank?
          production_items = Production.where(status: 'Production Inventory', is_active: true)
          
          bom_mappings = @parent_article.bom_mappings
          sku_codes = bom_mappings.pluck(:sku_code)
          
          if params[:tag_number].present?
            production_item = production_items.find_by(tag_number: params[:tag_number])
            raise 'No items available with this Tag ID' and return if production_item.blank?
            raise 'Tag ID does not match with BOM' and return unless sku_codes.include? production_item.sku_code
            
            data = production_item.as_json(only: %i[id tag_number sku_code uom quantity])
          else
            raise 'Article ID does not match with BOM' and return unless sku_codes.include? params[:sku_code]
            production_items = production_items.where(sku_code: params[:sku_code])
            raise 'No items available with this Article ID' and return if production_items.blank?
            production_item = production_items.last
            
            data = production_item.as_json(only: %i[sku_code uom])
            data[:quantity] = production_items.sum(:quantity)
          end
          render json: { data: data }
        end
        
        def update_item
          ActiveRecord::Base.transaction do
            work_in_progress_status = LookupValue.find_by(code: 'production_status_work_in_progress')
            production_items = Production.where(status: 'Production Inventory', is_active: true)
            # validate the items with bom articles
            bom_mappings = @parent_article.bom_mappings
            sku_codes = bom_mappings.pluck(:sku_code)
            
            item = production_items.find_by(id: params[:item_id])
            if item.present?
              raise 'Article ID does not match with BOM' and return unless sku_codes.include? item.sku_code
              
              item.update!(parent_id: @production.id, status_id: work_in_progress_status.id, status: work_in_progress_status.original_code)
            else
              items = production_items.where(sku_code: params[:sku_code])
              quantity = params[:quantity].to_i
              raise "Available Quantity is #{items.sum(:quantity)}" and return if quantity > items.sum(:quantity)
            
              items.limit(quantity).each do |item|
                item.update!(parent_id: @production.id, status_id: work_in_progress_status.id, status: work_in_progress_status.original_code)
              end
            end
            @production.production_status_in_progress! if @production.production_status_pending?
            render json: { production: @production.as_json(only: %i[id tag_number]), message: "Updated successfully" }
          end
        end
        
        def knit_items
          @parent_article
          ActiveRecord::Base.transaction do
            production_items = @production.children
            knitted_item_status = LookupValue.find_by(code: 'production_status_knitted_item')
            # validate the saved items required for knitting
            
            production_items.each do |production_item|
              production_item.update!(is_active: false, status_id: knitted_item_status.id, status: knitted_item_status.original_code)
            end
            @production.update!(production_status: :completed, is_active: true, toat_number: params[:toat_number])
            render json: { message: "Updated Tag ID '#{@production.tag_number}' moved to Semi & Finished Goods." }
          end
        end

        private

        def filter_productions
          status = params[:status] || 'Production Inventory'
          dc_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.where("site_category in (?)", ["R", "B"]).pluck(:id)
          @productions = Production.dc_filter(dc_ids).where(status: status, is_active: true).order('updated_at desc')

          if (params[:search].present? and params[:search_in].present?)
            search_data = params[:search].split_with_gsub
            if params[:search_in] == "tag_number"
              @productions = @productions.where(tag_number: search_data)
            elsif params[:search_in] == "sku_code"
              @productions = @productions.where(sku_code: search_data)
            end
          end
          @productions = @productions.where(sku_type_id: params[:sku_type]) if params[:sku_type].present?
          @productions = @productions.where(uom_id: params[:uom]) if params[:uom].present?
        end

        def get_productions
          @productions = Production.where(id: params[:ids], is_active: true)
          raise 'Invalid ID.' and return if @productions.blank?
        end
        
        def get_article
          @parent_article = ClientSkuMaster.find_by(id: params[:id])
          raise 'Invalid ID.' and return if @parent_article.blank?
        end
        
        def get_production
          @production = Production.find_by(id: params[:production_id], is_active: false)
          raise 'Invalid Production ID' and return if @production.blank?
        end

        def create_production
          status = LookupValue.find_by(code: 'production_status_finished_or_semi_finished_goods')
          production = Production.find_or_initialize_by(sku_code: @parent_article.code, is_active: false, production_status: :pending)
          
          if production.new_record?
            tag_number = "T-#{SecureRandom.hex(3)}"
            distribution_center_id = DistributionCenter.first.id
            client_id = Client.first.id
            client_category_id = @parent_article.client_category_id
            forward_inv = ForwardInventory.new(
              client_id: client_id, tag_number: tag_number, distribution_center_id: distribution_center_id, client_category_id: client_category_id, client_sku_master_id: @parent_article.id,
              sku_code: @parent_article.code, item_description: @parent_article.sku_description, item_price: @parent_article.mrp, mrp: @parent_article.mrp,
              map: @parent_article.map, asp: @parent_article.asp, brand: @parent_article.brand, details: {}, status_id: status.id, status: status.original_code
            )
            forward_inv.save!
            
            production.assign_attributes({
              forward_inventory_id: forward_inv.id, distribution_center_id: distribution_center_id, client_sku_master_id: @parent_article.id, tag_number: tag_number,
              item_description: @parent_article.sku_description, serial_number: forward_inv.serial_number, grade: forward_inv.grade,
              details: {}, status_id: status.id, status: status.original_code, item_price: forward_inv.item_price, uom: @parent_article.uom, uom_id: @parent_article.uom_id,
              sku_type: @parent_article.sku_type, sku_type_id: @parent_article.sku_type_id, quantity: 1, inwarded_date: Date.current
            })
            production.save!
          end
          production
        end
      end
    end
  end
end
