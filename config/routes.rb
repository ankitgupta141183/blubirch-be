Rails.application.routes.draw do

  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
	
  devise_for :users, path: '', path_names: { sign_in: 'login', sign_out: 'logout' }, controllers: { sessions: 'api/v1/sessions'}, path_prefix: '/api/v1'
  
  namespace :api do
    get '/v1/warehouse/cannibalization/to_be_cannibalized/generate_tag_number', to: 'v2/warehouse/cannibalization/to_be_cannibalized#generate_tag_number'
    get '/v1/warehouse/cannibalization/to_be_cannibalized/get_bom', to: 'v2/warehouse/cannibalization/to_be_cannibalized#get_bom'
    post '/v1/warehouse/cannibalization/to_be_cannibalized', to: 'v2/warehouse/cannibalization/to_be_cannibalized#index'
    post '/v1/warehouse/cannibalization/to_be_cannibalized/move_to_cannibalized', to: 'v2/warehouse/cannibalization/to_be_cannibalized#move_to_cannibalized'
    post '/v1/warehouse/cannibalization/to_be_cannibalized/move_to_work_in_progress', to: 'v2/warehouse/cannibalization/to_be_cannibalized#move_to_work_in_progress'

    namespace :v1 do
      post '/import_document', to: 'warehouse/wms/forward_master_data#forward_import_document'
      post '/import_gi_document', to: 'warehouse/wms/forward_master_data#import_gi_document'
      post '/doc_error_response', to: 'warehouse/wms/forward_master_data#doc_error_response'
      post '/export_inbound_documents', to: 'warehouse/wms/forward_master_data#export_inbound_documents'
      post '/export_outbound_documents', to: 'warehouse/wms/forward_master_data#export_outbound_documents'
      post '/distribution_centers', to: 'warehouse/wms/forward_master_data#distribution_centers'
      post '/vendor_masters', to: 'warehouse/wms/forward_master_data#vendor_masters'
      post '/sku_masters', to: 'warehouse/wms/forward_master_data#master_skus'
      post '/document_search', to: 'warehouse/wms/documents#search'
      post '/outbound_search', to: 'warehouse/wms/documents#outbound_search'
      get '/lookups', to: 'warehouse/wms/documents#lookups'
      post '/inbound_gr_response', to: 'warehouse/wms/inbound#inbound_gr_response'
      post '/outbound_gi_response', to: 'warehouse/wms/outbound#outbound_gi_response'
      post '/ean_search', to: 'warehouse/wms/documents#ean_search'
      post '/inbound', to: 'warehouse/wms/inbound#create'
      post '/outbound', to: 'warehouse/wms/outbound#create'
      post '/import_pkslip', to: 'warehouse/wms/forward_master_data#import_pkslip'
      post '/import_rtn_document', to: 'warehouse/wms/forward_master_data#import_rtn_document'
      get '/list_expectional_articles', to: 'warehouse/wms/forward_master_data#list_expectional_articles'
      get '/list_expectional_article_serial_number', to: 'warehouse/wms/forward_master_data#list_expectional_article_serial_number'
      get '/exp_articles_file_upload', to: 'warehouse/wms/forward_master_data#exp_articles_file_upload'
      post '/exp_articles_scan_ind_mapping', to: 'warehouse/wms/forward_master_data#exp_articles_scan_ind_mapping'
      post '/exp_articles_sr_no_length_mapping', to: 'warehouse/wms/forward_master_data#exp_articles_sr_no_length_mapping'
      get '/barcode_config', to: 'warehouse/wms/documents#barcode_config'

      resources :approval_configurations
      resources :approval_requests
      
      resources :password_resets do
        collection do
          post "send_otp"
          post "edit"
          post "reset"
          post "change_password"
        end
      end
      
      resources :client_categories do
        collection do
          get "all_category_data"
          get "get_test_rule"
          get "get_leaf_categories"
        end
      end

      resources :gradings do
        collection do
          get "fetch_regrade_inventories"
          get "category_rules"
          post "calculate_grade"
          post "store_grade"
          post 'update_ai_details'
          post 'send_images_to_ai'
        end
      end

      resources :lookups do
        collection do
          get "inventory_store_status"
          get "inventory_warehouse_status"
          get "logistics_order_types"
          get "country"
          get "states"
          get "cities"
          get "get_child_values"
          get "get_email_templates"
          get "reminder_status"
          get "get_distribution_center_types"
          get "get_dealer_types"

          get "get_customer_return_reasons"
          get "get_warehouse_reasons"
          get "get_client_categories"
          get "get_client_sku_masters"
          get "get_payment_types"
        end
      end

      resources :quotations do
        collection do
          post "lot_information"
          post "create_quotation"
          post "download_manifesto"
        end
      end

      namespace :store do

        resources :invoices do
          collection do
            get "fetch_inventories"
            get "get_return_reasons"
            get "fetch_invoice_inventories"
            post "no_grade_inventory"
            post "save_inventories"
          end
        end

        resources :pending_dispatch, only: [:index] do
          collection do
            post 'create_consignment'
            get 'logistics'
            get 'consignment_file_types'
            get 'get_selected_gate_passes'
          end
        end
        resources :pending_approvals do
          collection do 
            post "approve_request"
            post "set_reminder"
            get "fetch_inventories"
            post "reduce_inventory_count"
            post "destroy_inventory"
          end
        end
        resources :approvals do
          collection do
            get 'approved_requests'
            post 'approve_requests'
          end
        end
        
        resources :pending_packaging, only: [:index, :show] do
          collection do
            post 'add_packaging_box'
            post 'generate_gate_pass'
            post 'create_gatepass_items'
            delete 'delete_packaging_box'
          end
        end

        namespace :returns do
          resources :customer_returns do
            collection do
              get 'check_sku'
              get 'category_rules'
              post 'upload'
              post 'generate_rr'
              post 'finalize_grading'
              get 'warehouse_rules'
              post 'delete_images'
            end
          end
        end
      end
  

      namespace :warehouse do

        namespace :return_initiation do
          resources :master_values do
            collection do
              get :return_types
              get :channel_types
              get :return_sub_types
              get :return_reasons
              get :return_sub_reasons
              get :return_creation_locations
              get :return_creation_document_keys
              get :return_request_creation_status
              get :return_incident_damage_types
              get :return_type_of_loss 
              get :return_salvage_values
              get :return_incident_locations
              get :return_vendor_responsible
              get :sales_return_settlement_type
              get :return_initiation_dispostions
            end
          end
          
          resources :return_inventory_informations do 
            collection do
              post :search_return_items
            end
          end

          resources :return_eligibility_validations do 
            collection do 
              post :approve
              post :reject
              post :search
            end
          end

          resources :return_manual_dispositions do 
            collection do
              post :search
              post :assign_disposition
            end
          end

          resources :return_creation_file_uploads
          resources :return_creations do 
            collection do
              post :search
              post :delete_return_items
              post :create_return_items
            end
          end
          resources :return_items
          resources :return_approvals, only: [:index] do
            collection do
              get "get_settlement_methods"
              get "get_enums_data"
              post "approve_sales_return"
              post "reject_sales_return"
              post "approve_internal_return"
              post "reject_internal_return"
              post "approve_exchange_return"
              post "approve_warranty_return"
              post "approve_lease_return"
              post "reject_return_item"
              post "reject_warranty_return"
            end
          end
          resources :reverse_pickup, only: [:index] do
            collection do
              post :update_tag_numbers
              post :update_packaging_details
              get :reverse_pickup_items
              post :update_pickup_date
              post :assign_logistic_partner
              post :update_pickup_details
              post :import_dc_locations
            end
          end

        end
            
        resources :third_party_claims, only: [:index, :show] do
          collection do
            put 'update_cn_dn_number'
            get "get_filters_data"
          end
        end
        
        resources :liquidation_file_uploads
        resources :manual_processes do
          collection do
            post 'delete_item'
            post 'bucket_movement'
            get 'get_dispositions'
          end
        end
        resources :liquidations do
          collection do
            get 'fetch_inventories'
            get 'fetch_beam_inventories'
            get 'get_liquidation_images'
            get 'get_republish_liquidation_images'
            get 'generate_csv'
            post 'create_lots'
            post 'create_manual_dispatch_lot'
            post 'dispatch_offline_lot'
            post 'create_beam_lots'
            post 'create_beam_republish_lots'
            post 'create_beam_republish_lots_async'
            post 'republish_lots_callback'
            post 'create_contract_lots'
            post 'regrade_inventories'
            post 'moving_lot_creation'
            get 'fetch_pending_regrading_inventories'
            post 'update_liquidation_cell'
            post 'update_lot_order'
            get 'get_vendor_liquidation'
            get 'get_vendor_contract'
            post 'search_vendor'
            get 'get_quotations'
            get 'get_email_vendors_list'
            post 'update_lot_winner'
            post 'get_liquidation_images_page'
            post 'remove_excess_items_before_dispatch'
            post 'search_item'
            get 'get_dispositions'
            put 'set_disposition'
            get 'get_liquidation_requests'
            post 'move_to_pending_liquidation'
          end

        end

        resources :liquidation_orders, only: [:index] do
          collection do 
            get 'beam_orders'
            post 'publish_lot'
            post "update_lot_beam_status"
            post "extend_time"
            post 'delete_lot'
            post 'relive_lot'
            post 'winner_code_list' 
            post 'lot_inventory'
            get 'get_lot_details'
            post 'send_email_to_vendors'
            post 'approve_contract_lot'
            get 'get_contracted_price'
            post 'extend_lot_mail'
            post 'cancel_lot_mail'
            get 'get_quotations'
          end
        end

        resources :lots, only: [:index] do
          collection do
            post 'create_bids'
            post 'create_paid_bids'
          end          
        end

        resources :e_wastes do
          collection do
            get 'fetch_e_wastes'
            get 'generate_csv' 
            post 'update_ewaste_cell'
            get  'get_vendor_ewaste'
            post 'search_item'
          end
        end

        resources :e_waste_orders, only: [:index] do
          collection do 
            post 'create_lot'
            post 'update_lot_status'
            post 'delete_lot' 
            post 'winner_code_list'                 
          end          
        end 

        resources :e_waste_file_uploads
        resources :stock_transfers do
          collection do
            
            post 'assign_disposition'
            post 'transfer'
            post 'update_rsto'
            
          end
        end
        resources :item_informations do
          collection do
            get 'search'
          end
        end
        resources :inventories do
          collection do
            get 'pending_grade'
            get 'item_info'
            get 'search_inventory'
            get 'document_search'
            post 'search_items'
            get 'rtv'
            get 'restock'
            get 'repair'
            get 'liquidation'
            get 'ewaste'
            get 'pending_issues'
            post 'assign_new_stn'
            get 'alert_inventories'
            get 'disposition_criticality_count'
            get 'inventory_status_count'
            get 'bucket_alert_records'
            get 'get_dispositions'
            patch 'update_serial_number'
          end
        end
        resources :warehouse_grading do
          collection do
            get 'check_sku'
            get 'category_rules'
            post 'upload'
            post 'generate_rr'
            post 'finalize_grading'
            get 'warehouse_rules'
            post 'delete_images'
          end
        end
        resources :gate_passes do
          collection do
            get "fetch_gate_passes"
            post "create_consignment_box"
            post "update_box_detail"
            post "complete_consignment"
            get "get_box_conditions"
            get "consignment_box_file_types"
            post "import"
          end
        end
        resources :quality_control do
          collection do
            get "fetch_inventories"
            post "complete_qc"
          end
        end

        resources :stowing do 
          collection do
            get "fetch_inventories"
            post "set_location"
            post "complete_stowing"
          end
        end

        resources :users do 
          collection do
            get "fetch_buckets_info"
            get "fetch_all_info"
            patch "restore_user"
          end
        end
        
        resources :alert_inventories
        resources :variation_reports
        # resources :repairs do
        #   collection do
        #     post "upload"
        #     post "delete_images"

        #   end
        #   member do
        #     post "pending_repair"
        #     post 'create_job_sheet'
        #   end
        resources :new_repairs, only: [:index, :show] do
          collection do
            put 'update_details'
            put 'update_pending_quotation'
            put 'create_dispatch_items'
            get 'index_new'
            get 'get_filters_data'
            post 'update_disposition_item'
            put 'reject_disposition_item'
            get 'repair_dispatch_item'
            put 'update_repair_details'
            post 'search_item'
            get 'get_vendor_master'
            get 'repair_dispatch_items'
            get 'get_dispositions'
            put 'update_disposition'
          end
        end

        resources :redeploy, only: [:index] do
          member do
            put :update_redeploy_details
          end
          collection do
            get :get_distribution_centers
            post :create_redeploy_dispatch_order
            get :get_vendor_redeploy
            post 'search_item'
            get 'get_dispositions'
            put 'set_disposition'
          end  
        end

        resources :restocks, only: [:index, :show] do
          member do
            put :update_restock_details
          end
          collection do
            get :restock_dispatch_items
            post :create_restock_dispatch_order
            get :get_master_vendor
            get :get_filters_data
            get :restock_dispatch_item
          end
        end

        resources :pending_packaging, only: [:index] do
          collection do
            get "get_inventories"
            post "create_box"
            post "generate_gate_pass"
            post "create_items"
            delete "delete_packaging_box"
          end
        end

        resources :dispatch do 
          collection do 
            get 'fetch_orders'
            get 'dispatch_boxes'
            post 'create_pick_up_request'
            post 'create_packaging_request'
            put 'update_sub_location'
            get 'get_filters_data'
            post 'update_dispatch_details'
            post 'set_disposition'
            get 'get_dispositions'
          end
          member do 
            get "add_items"
            put "write_off"
          end
        end

        resources :warehouse_dispatch do
          collection do
            get "get_selected_gate_passes"
            get "logistics"
            post 'create_consignment'
            get 'consignment_file_types'
          end
        end

        resources :pick_item, only: [:index] do
          collection do
            get "get_inventories"
            post "create_items"
          end
        end
        resources :inward, only: [] do
          collection do
            get "get_sku_details"
            post "create_inventory"
          end
        end

        resources :return_to_vendor, only: [:index] do
          collection do
            post 'send_for_claim'
            get 'get_dispositions'
            post 'approve_reject_inventory'
            post 'send_reminder_or_escalation'
            post 'resubmit_inventories'
            put 'set_disposition'
            put 'set_disposition_on_claim'
            put 'update_call_log'
            post 'update_inspection_details'
            post 'send_for_escalation'
            post 'claim_settlement'
            post 'create_dispatch_items'
            get 'get_vendor_master'
            post 'edit_information'
            post 'search_item'
          end
        end
        
        resources :brand_call_logs, only: [:index, :show] do
          collection do
            put 'update_ticket'
            put 'update_inspection_details'
            get 'get_brand_decisions'
            put 'update_approval_details'
            get 'get_pending_documents'
            post 'bulk_update_docs'
            get 'get_dispositions'
            post 'update_disposition'
            post 'set_disposition'
          end
          member do
            put 'update_document'
            put 'update_claim_amount'
          end
        end

        resources :markdowns, only: [:index] do
          collection do 
            get 'get_distribution_center'
            get 'get_vendor_markdown'
            post 'markdown_update'
            post 'markdown_dispatch_complete'
            post 'search_item'
          end
        end

        resources :insurances, only: [:index] do
          collection do
            get 'get_vendor_insurance'
            get 'get_dispositions'
            post 'submit_for_insurance'
            put 'update_call_log'
            post 'submit_inspection'
            post 'approve_reject_insurance'
            put 'set_disposition'
            post 'create_dispatch_items'
            post 'search_item'
          end
        end
        
        resources :new_insurances do
          collection do
            put 'update_claim_ticket'
            put 'update_inspection_details'
            get 'get_claim_decisions'
            put 'update_approval_details'
            get 'get_pending_documents'
            post 'bulk_update_docs'
            get 'get_dispositions'
            post 'update_disposition'
            post 'set_disposition'
          end
          member do
            put 'update_document'
            put 'update_claim_amount'
          end
        end
        
        resources :insurers do
          collection do
            get 'get_insurer_configs'
            delete "bulk_delete"
          end
        end

        resources :pending_dispositions, only: [:index] do 
          collection do
            post 'set_disposition'
            get 'get_dispositions'
            post 'search_item'
          end
        end

        resources :replacements, only: [:index, :show] do
          collection do
            put 'update_confirmation'
            get 'get_dispositions'
            get 'get_sku_records'
            post 'submit_for_inspection'
            post 'submit_inspection'
            post 'approve_reject_replacement'
            put 'set_disposition'
            post 'create_replacement'
            post 'search_item'
            get 'dispatch_items'
          end
          member do
            get 'dispatch_item'
          end
        end

        resources :company_stocks do
          collection do
            post 'upload_stock'
          end
        end
        
        resources :sub_locations do
          collection do
            get "get_locations"
            delete "bulk_delete"
            get "sub_location_rules"
            get "rule_types"
            post "update_rules"
            get "export_sublocations"
            post "import_sublocations"
            get "export_sublocation_sequence"
            post "import_sublocation_sequence"
          end
        end
        resources :put_requests do
          collection do
            post "cancel_request"
            get "location_users"
            post "update_assignee"
            get "filters_data"
          end
          get "add_items", on: :member
          put "mark_as_not_found", on: :member
        end
        resources :put_away, only: [:index] do
          collection do
            get "not_found"
            put "update_sub_location"
            get "request_reasons"
            get "sub_locations"
            get "get_dispositions"
            get "all_inventories"
            get "filters_data"
            get "export_inventory"
            post "import_inventory"
          end
          put "write_off", on: :member
        end
        resources :distribution_centers do
          member do
            get "sub_location_sequence"
            put "update_sequence"
          end
        end
        resources :prd, only: [:index, :show, :update] do
          collection do
            get 'filters_data'
            get 'get_irrd_items'
            get 'get_ird_items'
            get 'download_items'
            get 'download_irrd_items'
            get 'download_ird_items'
            get 'download_prd_sample'
            delete 'delete_items'
            get 'file_uploads'
            post 'upload_file'
            post 'update_approval'
            post 'reject'
          end
        end
        
        namespace :wms do

          resources :documents do 
            collection do 
              post 'search_documents'
              get 'get_item_list'
              post 'search_outbound_documents'
              get 'get_outbound_item_list'
              get 'get_error_documents'
              get 'users_list'
              get 'dc_list'
              get "assign_user"
              get "assign_outbound_user"
              get "list_outbound_documents"
            end
          end

          resources :gate_passes do
            collection do
              get 'client_category_grading_rules'
              get 'disposition_rules'
              get 'generate_tag'
              get 'return_reasons'
              get 'category_rules'
              get 'stn_search'
              get 'search_sku'
              post 'serial_verification'
              post 'update_inventory'
              post 'calculate_grade'
              post 'calculate_grade_new'
              post 'update_inwarding_details'
              post 'create_inventories'
              post 'proceed_grn'
              post 'update_grn'
              get 'export_pending_grn_inventories'
              get 'get_grn_data'
              get 'export_inward_visibility_report'
              get 'export_outward_visibility_report'
              get 'timeline_report'
              get 'export_daily_report'
            end
          end
          resources :stowing do 
            collection do
              get "fetch_inventories"
              get "unstowed_items"
              post "set_location"
              post "complete_stowing"
            end
          end
          resources :pick do 
            collection do
              get "fetch_orders"
              post "update_toat"
              post "pick_confirm"
              post 'cancel_lot'
              post 'edit_lot'
              post 'remove_item_from_lot'
              post 'adjust_amount'
            end
          end
          resources :pack do 
            collection do
              get "fetch_orders"
              post "assign_box"
              post "create_box"
              post "dispatch_confirm"
              post "delete_box"
              post "remove_item"
            end
          end
          resources :dispatch do 
            collection do
              get "fetch_orders"
              post "dispatch_initiate"
              post "dispatch_initiate_new"
              post "dispatch_complete"
              post "close_beam_lot"
              get "pending_dispatch"
              get 'destination_based_boxes'
              post 'update_dispatch_details'
            end
            member do 
              get "request_details"
              put 'update_pick_up_request'
              put 'update_putaway_item'
              put "add_box"
              put "submit_pick_up_request"
              put "submit_packaging_request"
            end
          end
          resources :put_away, only: [:index, :show] do
            member do
              get "get_sub_locations"
              put "update_sub_location"
              put "add_toat"
              put "submit_request"
              # put "update_pick_up"
            end
          end
          
        end

        resources :inventory_file_uploads do
          collection do
            get 'get_edit_lot_images'
          end
        end
        
        resources :consignment, only: [] do
          collection do
            get :get_logistics_partners
            post :generate_receipt_summary
          end
          member do
            post :submit_consignment_details
          end
        end
        resources :item_inward, only: [] do
          collection do
            get 'prd_info'
            post 'auto_inward'
            get 'grading_questions'
            get 'fetch_item'
          end
          member do
            get 'get_box_items'
            post 'compute_grade'
            post 'update_tag_number'
            post 'complete_ird'
            post 'generate_grn'
          end
        end
        resources :inward_tracking, only: [:index, :show] do
          collection do
            post 'generate_grn'
          end
        end
      end
      
      namespace :forward do
        resources :replacements, only: [:index, :show] do
          collection do
            put :reserve
            put :reserve_items
            put :un_reserve
            get :get_payment_details
            get :get_buyers
            get :get_dispositions
            post :set_disposition
          end
          member do 
            get :item_details
            put :update_payment_details
          end
        end
        
        resources :demos, only: [:index, :show] do
          collection do
            get :get_dispositions
            get :get_locations
            post :set_disposition
            post :transfer
          end
        end
        
        resources :productions, only: [:index] do
          collection do
            get :filters_data
            get :get_dispositions
            post :set_disposition
            post :update_production_inventory
            get :get_finished_articles
          end
          member do
            get :bom_details
            get :item_details
            put :update_item
            put :knit_items
          end
        end
      end

      resources :categories do
        collection do
          get "test_rules"
          get "grading_rules"
          get "client_category_grading_rules"
          get "all_category"
          get "leaf_category"
          get "get_details"
        end
      end

      namespace :pos do
        resources :coupan_codes
        resources :customer_informations
        resources :pos_invoices
        resources :purchase_orders
        resources :stock_skus
        resources :payment_types
        resources :dealer_orders do
          collection do
            get "get_client_sku_master"
          end
        end
        resources :dealer_customers do
          collection do
            get "get_dealer_customer"
          end
        end
        resources :dealer_order_inventories do
          collection do
            get "get_dealer_order_inventory"
          end
        end
        resources :dealer_invoices
      end

      namespace :dms do
        resources :dealers
        resources :dealer_order_approvals do
          collection do
            post "approve_reject_order"
            post "update_dealer_order_item"
            get "dealer_order_list"
            post "dealer_order_item_list"
          end
        end
      end

      resources :items do
        collection do
          post :create_bulk_inwards_file_import
          post :consignment_inward
          post :box_inwards
          post :box_receipt_summary
          get :pending_box_resolutions
          get :boxes
          get :inwarded_items
          post :item_inwards
          post :grading_before_inwards
          get :pending_item_resolutions
          put :accept
          put :send_to_customer
          put :send_to_consignor
          put :rejected
          put :write_off
          put :send_to_consignor
          put :update_grn
          get :rejected_boxes
          put :update_pending_dispatch
          put :update_pending_receipt
          get :item_details
          get :item_attributes
          put :mismatch_update
          get :box_conditions
          get :article_inward_type
          get :grading_questions
          post :compute_grade
          post :submit_grades
          get :item_mismatch_claim
          get :item_grade_mismatch_claim
          get :logistic_partner_claims
          post :no_claims
          post :raise_debit_notes
          post :upload_damage_certificate
          get :pending_return_requests
          post :approve_return_request
          post :reject_return_request
          get :pending_item_inwarding
        end
      end

      resources :logistics_partners
      resources :distribution_centers
      resources :vendor_masters, only: :index
      resources :physical_inspections do
        member do
          get :issue_items
        end
        collection do
          post :scan_inventories
          post :update_status
          post :update_assignees
          get :brands
          get :articles
          get :categories
          get :dispositions
          get :assignees
          get :get_sub_locations
        end
      end
      resources :issue_inventories, only: :index do
        collection do
          post :update_status
          get :pending_approvals
          post :reject
          post :correct_excess
          post :approve
          get :get_filter_locations
        end
      end
      resources :scan_inventories, only: :show, param: :tag_number
      resources :transfer_inventories, only: :index do
        collection do
          get :dispositions_type
          get :dispositions
          get :dispositions_sub_status
          post :transfer_inventories
        end
      end
    end
  end


  namespace :api do
    namespace :v2 do
      namespace :warehouse do
        namespace :liquidation do
          resources :channel_allocations, only: :index do
            collection do
              post :index
              post :mark_e_waste
              get :category_list
              get :formatted_category_list
              post :allocate_channel
            end
          end
          resources :price_discovery, only: :index do
            collection do
              post :index
              post :assign_price
            end
          end

          resources :competitive_bidding_price, only: [:index] do
            collection do
              post :index
              post :create_lot
              post :move_to_moq
              post :auto_lot
              get :buyers
              get :inventories_images
              get :calculate_ai_price
            end
          end

          resources :contracted_price, only: [:index] do
            collection do
              get :get_vendor_contract
              post :index
              post :create_lot
            end
          end

          resources :b2c_pending_publish, only: :index do
            collection do
              post :index
              post :move_to_b2b
              post :publish
              post :resync_publish
              get :get_platform_list
            end
          end

          resources :moq, only: [:index, :create] do
            collection do
              post :index
              post :create_lot
              post :move_to_competative_bidding
              post :liquidation_quantity_based_on_grade
              get :article_id_list
              get :article_description_list
              get :buyers
              post :mrp_per_lot
            end
          end
        end

        namespace :oms do
          namespace :forward do
            resources :purchase_orders, only: [:create, :index, :show] do 
              member do
                get :items
                get :detail
              end
              collection do
                get :vendors
                get :inventories_data
                get :locations
                get :tally_records
              end
            end
            resources :purchase_order_receipt_challans, only: [:create, :index] do
              collection do
                get :details
              end
            end
          end
          namespace :reverse do
            resources :sales_orders, only: [:index, :create, :show] do
              collection do
                post 'index'
                post :item_details
                post :create_invoice
                get :article_id_list
                get :article_description_list
                get :vendor_details
                get :location_details
                get :tally_records
                get :print_order
                put :cancel_order
              end
              member do
                get :items
              end
            end
            resources :back_orders, only: [:index, :create, :show] do
              collection do
                post 'index'
                post :move_to_so
                post :item_details
                put :cancel_order
                get :tally_records
                get :print_order
              end
              member do
                get :items
              end
            end
            resources :lease_orders, only: [:index, :create, :show] do
              collection do
                post 'index'
                post :item_details
                get :article_id_list
                get :article_description_list
                get :vendor_details
                get :location_details
                get :tally_records
                get :print_order
                put :cancel_order
              end
              member do
                get :items
              end
            end
            resources :replacement_customer_orders, only: [:index, :create, :show] do
              collection do
                post 'index'
                post :item_details
                get :tally_records
                get :print_order
                put :cancel_order
              end
              member do
                get :items
              end
            end
            resources :outward_return_orders, only: [:index, :create, :show] do
              collection do
                post 'index'
                post :item_details
                get :tally_records
                get :print_order
                put :cancel_order
              end
              member do
                get :items
              end
            end
            resources :transfer_orders, only: [:index, :create, :show] do
              collection do
                post 'index'
                post :item_details
                get :tally_records
                get :print_order
                put :cancel_order
              end
              member do
                get :items
              end
            end
            resources :repair_orders, only: [:index, :create, :show] do
              collection do
                post 'index'
                post :item_details
                get :tally_records
                get :print_order
                put :cancel_order
              end
              member do
                get :items
              end
            end
            resources :replacement_orders, only: [:index, :create, :show] do
              collection do
                post 'index'
                post :item_details
                get :tally_records
                get :print_order
                put :cancel_order
              end
              member do
                get :items
              end
            end
          end
        end

        resources :order_management_systems, only: [:create, :index, :show] do 
          member do
            get :items
          end
          collection do 
            get :tally_records
          end
        end

        resources :liquidations

        resources :return_inventories, only: [:create, :show] do
          collection do 
            get :inventories
            put :update_record
          end
        end

        resources :callbacks do
          collection do
            post :publish
            post :place_bid
            post :buy_now
            post :extend_bid
            post :bid_end
            put :b2c_publish
            put :extend_b2c_time
            put :b2c_product_buyer_details
          end
        end

        resources :saleables, only: [:index, :show] do
          collection do
            put :reserve
            put :reserve_items
            put :update_disposition
            put :un_reserve
            get :get_payment_details
            put :update_payment_details
            post :create_buyer
            get :get_buyers
            get :get_city_and_states
            get :dispositions
            post :set_dispositions
          end
          member do 
            get :item_details
          end
        end

        namespace :liquidation_order do
          namespace :b2b do
            resources :in_progress, only: [:index, :show, :update, :destroy] do
              collection do
                get  :vendor_list
                post :index
                post :reserve
                post :update_timing
                post :delete_lots
              end
            end
            resources :pending_publish, only: [:index, :show, :update, :destroy] do
              member do
                get :lot_details
                get :lot_images
                post :remove_lot_items
              end

              collection do
                post :index_new
                get :index_new
                post :index
                post :publish
                post :update_timing
                post :delete_lots
              end
            end
          end
          namespace :b2c do
            resources :in_progress, only: [:index, :update, :destroy] do
              collection do
                post :index
                post :update_sales
                post :delete_lots
              end
            end
          end

          namespace :pending do
            resources :decision, only: [:index, :update, :destroy] do
              collection do
                post :index
                post :republish
                post :republish_callback
                get :get_bidders
                post :delete_lots
              end
            end
            resources :b2c_decision, only: [:index]
            resources :dispatch_confirmation_time, only: :index do
              collection do
                post :index
                post :update_dispatch_date
              end
            end
            resources :payment, only: [:index, :update] do
              collection do
                post :index
                post :cancel
                post :unreserve_sub_lot
              end
            end
          end
          resources :dispatch, only: :index do
            collection do
              post :index
            end
          end
        end
        resources :liquidation_orders
        resources :ecom_liquidations, only: :index do
          collection do
            post :dispatch_orders
          end
        end

        namespace :vendor_return do
          resources :pending_confirmation, only: [:index] do
            collection do
              get  :brand_list
              get  :vendor_list
              post :index
              post :update_confirmation
            end
          end
          resources :dispatch, only: :index do
            collection { post :index }
          end
        end
        namespace :markdown do
          resources :pending_price_and_location, only: :index do
            collection do
              post :index
              post :update_markdowns
              get  :filter_categories
              get  :filter_grade
              get  :get_distribution_center
            end
          end
          resources :dispatch, only: :index do
            collection do
              post :index
            end
          end
        end
        resources :markdowns

        resources :capital_assets, only: [:index] do
          collection do
            get  :get_dispositions
            get  :get_distribution_users
            post :index
            post :assigned_user
            post :unassigned_user
            post :set_dispositions
          end
        end

        namespace :rental do
          resources :reserve, only: :index do
            collection do
              get  :get_dispositions
              get  :article_ids_with_quantity
              get  :vendor_master_details
              post :index
              post :create_rental_reserve
              post :change_disposition
            end
          end
          resources :pending_payment, only: :index do
            collection do
              post :index
              post :update_status
              post :unreserve
            end
          end
          resources :out_for_rental, only: :index do
            collection do
              post :index
              post :update_rental
            end
          end
        end
        resources :rentals

        resources :inventory_file_uploads, only: [:index, :create] do
          collection do
            post :download_competitive_liquidations
          end
        end

        namespace :cannibalization do
          resources :cannibalized, only: :index do
            collection do
              get :get_dispositions
              post :index
              post :change_disposition
            end
          end
          resources :to_be_cannibalized, only: :index do
            collection do
              get :get_dispositions
              get :generate_tag_number
              post :index
              post :move_to_cannibalized
              get :get_bom
              post :move_to_work_in_progress
              post :change_disposition
            end
          end
          resources :work_in_progress, only: :index do
            collection do
              post :index
            end
          end
        end
        resources :cannibalizations
      end

      resource :account_setting, only: :show

      resources :dashboard, only: :index do
        collection do
          get 'dashboard_embed_url'
          get :ai_discrepancy_reports
        end
        member do
          get :ai_discrepancy_report
        end
      end

      resource :ondc do 
        collection do
          post :register
          post :on_search
          post :on_select
          post :on_init
          post :on_confirm
          post :on_status
          post :on_cancel
          post :on_update
          post :on_track
        end
      end

      resources :buyer_masters, only: :create
    end
  end

  namespace :admin do

    resources :return_inventory_informations

    resources :vendor_masters do
      member do
        get 'uploaded_rate_cards'
        get 'export_rate_cards'
      end
      collection do
        post "import"
        post 'delete_vendor'
      end
    end

    resources :disposition_rules

    resources :distribution_centers do 
      collection do
        post "distribution_center_uploads"
        get "search"
        post "sync_scb_org_data"
      end
    end

    resources :roles
    resources :alert_configurations do
      collection do
        post "import"
      end
    end
    resources :repair_parts do
      collection do
        post "import"
      end
    end
    resources :orders do 
      collection do
        post "import"
      end
    end
    resources :lookup_keys do
      collection do
        post "import"
      end
    end
    resources :lookup_values do
      collection do
        post "import"
        get "search"
        get "get_lookup_value_parents"
      end
    end
    resources :attribute_masters do
      collection do
        post "import"
      end
    end
    resources :categories do
      collection do
        post "import"
        get "get_category_parents"
      end
    end
    resources :clients do
      collection do
        get "search"
      end
    end
    resources :users do
      collection do
        get "search"
        get "get_username"
      end
    end
    resources :master_file_uploads do 
      member { patch :retry_upload }
      collection do 
        get "fetch_grading_type"
        get "fetch_distribution_centers"
      end
    end
    

    resources :client_categories do
      collection do
        post "import"
        get "get_client_category_parents"
        get "get_all_client_category"

      end
    end 
    resources :client_category_mappings do
      collection do
        post "import"
      end
    end

    resources :rules do
      collection do
        post "import"
        post "import_client"
      end
    end
    resources :client_attribute_masters do
      collection do
        post "import"
      end
    end  
    resources :client_sku_masters do
      collection do
        post "import"
      end
    end
    resources :channels do
      collection do
        get "search_filter"
      end
    end  

    resources :cost_values do 
      collection do
        post "import"
      end
    end
    resources :cost_labels
    resources :customer_return_reasons do
      collection do 
        post "import"
      end
    end
    resources :email_templates do
      collection do 
        post "import"
      end
    end
    resources :reminders do
      collection do
        post "import"
      end
    end
    resources :invoices do
      collection do
        post "import"
      end
    end

    resources :invoice_inventory_details do
      collection do
        post "import"
      end
    end
    resources :logistics_partners
    resources :qc_configurations

  end


  # Route for handling routing errors.
  # Note :: Please add any new route before this, As route added after this wont get hit.
  root 'home#index'
  get '*path', to: 'errors#not_found'
end
