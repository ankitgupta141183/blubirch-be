# frozen_string_literal: true

module Api
  module V1
    module Warehouse
      class ThirdPartyClaimsController < ApplicationController
        def index
          # & Setting Pagination
          set_pagination_params(params)

          # & Records
          @third_party_claims = ThirdPartyClaim.joins(:inventory)

          # & Tab based conditions
          statuses = ThirdPartyClaim.statuses
          stage_names = ThirdPartyClaim.stage_names
          if params['tab'].blank? || params['tab'] == 'Recovery'
            @third_party_claims = @third_party_claims.where("third_party_claims.status = #{statuses[:pending]} and stage_name != #{stage_names[:repair_cost]}")
          elsif params['tab'] == 'Cost'
            @third_party_claims = @third_party_claims.where("third_party_claims.status = #{statuses[:pending]} and stage_name = #{stage_names[:repair_cost]}")
          elsif params['tab'] == 'Closed'
            @third_party_claims = @third_party_claims.where("third_party_claims.status = #{statuses[:closed]}")
          end
          @third_party_claims = @third_party_claims.order('third_party_claims.updated_at desc')

          # & Filters
          if params['tag_number'].present? # ! Search part
            tag_numbers = params['tag_number'].split(',').collect(&:strip).flatten
            @third_party_claims = @third_party_claims.where(tag_number: tag_numbers)
          end

          @third_party_claims = @third_party_claims.where(claim_raised_date: params[:claim_raised_date].to_date) if params[:claim_raised_date].present?
          @third_party_claims = @third_party_claims.where(vendor_code: params[:vendor_code]) if params[:vendor_code].present?
          @third_party_claims = @third_party_claims.where(stage_name: ThirdPartyClaim.stage_names[params[:stage_name]])  if params[:stage_name].present?
          @third_party_claims = @third_party_claims.where(note_type: ThirdPartyClaim.note_types[params[:note_type]])  if params[:note_type].present?
          @third_party_claims = @third_party_claims.where(cost_type: ThirdPartyClaim.cost_types[params[:cost_type]])  if params[:cost_type].present?

          # & Pagination
          @third_party_claims = @third_party_claims.page(@current_page).per(@per_page)

          # & Rendering the data
          render json: @third_party_claims, meta: pagination_meta(@third_party_claims)
        end

        def get_filters_data
          # & Reterive Records
          vendors = VendorMaster.joins(:vendor_types)
                                .where('vendor_types.vendor_type': ['Brand Call-Log', 'Internal Vendor'])
                                .where.not(vendor_code: current_user.distribution_centers.pluck(:code)).distinct
          stage_names = ThirdPartyClaim.stage_names.keys.collect { |stage_name| { id: stage_name, name: stage_name.humanize } }
          note_types = ThirdPartyClaim.note_types.keys.collect { |note_type| { id: note_type, name: note_type.humanize } }
          cost_types = ThirdPartyClaim.cost_types.keys.collect { |cost_type| { id: cost_type, name: cost_type.humanize } }

          # & Rendering the data
          render json: { vendors_data: vendors, stage_names: stage_names, note_types: note_types, cost_types: cost_types }
        end

        def show
          # & Getting Record
          @third_party_claim = ThirdPartyClaim.find(params[:id])

          # & Rendering the data
          render json: @third_party_claim
        end

        def update_cn_dn_number
          # & Validation to check whether credit/debit note is present or not
          credit_debit_note_number = params[:credit_debit_note_number]
          raise CustomErrors, 'Credit/Debit note number cannot be blank!' if credit_debit_note_number.blank?

          # & Getting Record
          @third_party_claims = ThirdPartyClaim.where(id: params[:ids])

          # & Updating Third Party Data
          @third_party_claims.find_each { |third_party_claim| third_party_claim.update!(credit_debit_note_number: credit_debit_note_number, status: :closed) }

          render json: "#{@third_party_claims.count} item successfully closed", status_code: 204
        end
      end
    end
  end
end
