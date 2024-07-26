class LiquidationOrder < ApplicationRecord

  include LiquidationOrderSearchable
  include Filterable
  include Lotable

    acts_as_paranoid
    has_many :liquidations
    has_many :inventories, through: :liquidations
    has_many :inventory_grading_details, { through: :inventories, source: 'inventory_grading_detail' }
    has_many :warehouse_orders , as: :orderable
    has_many :liquidation_order_histories, dependent: :destroy
    has_many :bids
    has_many :quotations
    has_many :vendor_quotation_links
    has_many :lot_attachments, as: :attachable
    has_many :approval_requests, as: :approvable
    belongs_to :liquidation_request, optional: true
    has_many :sub_lots, class_name: 'LiquidationOrder', foreign_key: :liquidation_order_id
    belongs_to :parent_lot, class_name: 'LiquidationOrder', foreign_key: :liquidation_order_id, optional: true
    has_many :moq_sub_lots, class_name: 'LiquidationOrder', foreign_key: :moq_order_id
    belongs_to :moq_parent_lot, class_name: 'LiquidationOrder', foreign_key: :moq_order_id, optional: true
    belongs_to :created_by, class_name: 'User', foreign_key: :created_by_id, optional: true
    belongs_to :updated_by, class_name: 'User', foreign_key: :updated_by_id, optional: true

    has_many :moq_sub_lot_prices, dependent: :destroy

    # validates :lot_name, uniqueness: true
    validates_uniqueness_of :order_number, :case_sensitive => false, allow_blank: true

    after_create :update_lot_name_and_order_number
    # after_create :sync_to_ai_ml
    # before_save :update_higest_bid
    before_save :update_floor_price
    after_update :update_status_to_beam, if: :saved_change_to_status?
    after_update :update_pending_publish_status, if: Proc.new { ["Ready for publishing", "Pending lot details", "Publish Initiated", "Publish Error", "Ready For Republishing"].include?(self.status) && !saved_change_to_status? }
    # after_commit :extend_time_to_reseller, on: :update, if: :start_and_end_time_changed?
    after_update :set_distribution_center_id
    before_save :update_bench_mark_price

    scope :emailed, -> { where("liquidations.details ->> 'email_sent' = ?", 'true') }
    scope :not_emailed, -> { where("liquidations.details ->> 'email_sent' = ?", 'false') }
    scope :with_lot_type, -> (lot_type) { where(lot_type: lot_type ) }
    scope :with_status, -> (status) { where(status: status) }
    scope :filter_by_status, -> (status) { where("liquidation_orders.status IN (?)", status) }
    scope :filter_by_price_discovery_method, -> (lot_type) { where("liquidation_orders.lot_type IN (?)", lot_type) }
    scope :filter_by_payment_status, -> (payment_status) { where("liquidation_orders.payment_status IN (?)", payment_status) }
    scope :filter_by_buyer_name, -> (buyer_name) { where("liquidation_orders.buyer_name IN (?)", buyer_name) }
    scope :publishable_lots, -> { where(status: ["Ready for publishing"], beam_lot_response: nil, republish_status: nil).where("? BETWEEN start_date AND end_date", Time.current) }
    scope :republishable_lots, -> { where(status: ["Ready For Republishing"], republish_status: 'republishing').where("? BETWEEN start_date AND end_date", Time.current) }

    enum republish_status: { pending: 0, success: 1, error: 2, republishing: 3 }, _prefix: :republish
    enum platform: { beam: 0, amazon: 1, flipkart: 2 }

    # def sync_to_ai_ml
    #   AiMlSyncWorker.perform_async(self.id)
    # end

    # def inventories
    #   Inventory.joins(liquidation: :liquidation_order).where(liquidation: { liquidation_orders: { id: self.id }})
    # end

    def ai_price
      self.details["ai_price"]
    end

    # LiquidationOrder.update_in_progress_b2b_lot_status
    #! Added in cron job until vaibhav added this from remarketing side
    def self.update_in_progress_b2b_lot_status
      LiquidationOrder.where("status = ? AND end_date < ?", "In Progress B2B", DateTime.now).each do |lot|
        reserve_price = lot.reserve_price
        bids = lot.bids
        if bids.present?
          highest_bid_price = lot.bids.sort_by(&:bid_price).last.bid_price
          if highest_bid_price.to_f > reserve_price.to_f
            status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_payment)
          else
            status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_decision)
          end
        else
          status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_decision)
        end
        lot.update!(status: status.original_code, status_id: status.id)
      end
    end

    def update_floor_price
      if floor_price_changed? && self.changes["floor_price"].present?
        old_floor_price = self.changes["floor_price"][0]
        if old_floor_price.to_f < 1
          old_floor_price = liquidations.pluck(:floor_price).compact.map(&:to_f).sum
        end
        liquidations.each do |liquidation|
          next if liquidation.floor_price.blank? || old_floor_price.to_f == 0
          floor_price_percent = (liquidation.floor_price.to_f/old_floor_price.to_f)*100
          liquidation.floor_price = (self.floor_price.to_f * (floor_price_percent.to_f/100)).round.to_f
          liquidation.save
        end
      end
    end

    def publish_to_beam(current_user)
      url =  Rails.application.credentials.beam_url+"/api/lots/create_lot"
      extra_attributes = { current_user: current_user }
      publish_lot_to_client url, BeamLotPublishSerializer, extra_attributes
    end

    def publish_to_reseller(current_user)
      url = Rails.application.credentials.reseller_url+"/api/lots"
      extra_attributes = { current_user: current_user }
      serializer = is_moq_lot? ? ::Api::V2::ResellerMoqLotPublishSerializer : ::Api::V2::ResellerLotPublishSerializer
      publish_lot_to_client url, serializer, extra_attributes
    rescue => e
      return e.response
    end

    def republish_to_beam(old_lot_name, current_user)
      url = Rails.application.credentials.beam_url+"/api/lots/republish_lot"
      extra_attributes = { old_bid_name: old_lot_name, current_user: current_user }
      publish_lot_to_client url, BeamLotPublishSerializer, extra_attributes
    end

    def republish_to_beam_async old_lot_name, params = {}
      url = Rails.application.credentials.beam_url+"/api/lots/republish_lot_async"
      extra_attributes = { old_bid_name: old_lot_name, original_params: params, current_user: params.delete(:current_user) }
      publish_lot_to_client url, BeamLotPublishSerializer, extra_attributes
    end

    def republish_to_reseller(current_user)
      url = Rails.application.credentials.reseller_url+"/api/lots/republish_lot"
      self.reload
      extra_attributes = { current_user: current_user }
      serializer = is_moq_lot? ? ::Api::V2::ResellerMoqLotPublishSerializer : ::Api::V2::ResellerLotRepublishSerializer
      publish_lot_to_client url, serializer, extra_attributes
    end

    def publish_lot_to_client url, serializer, extra_attrs={}
      serializable_resource = ActiveModelSerializers::SerializableResource.new(self, each_serializer: serializer, adapter: :attributes, adapter_options: extra_attrs.merge({ account_setting: AccountSetting.first })).as_json
      serializable_resource.merge!(extra_attrs.except(:current_user))
      RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
    rescue => e
      return e.response
    end

    def update_liquidation_status(lot_status, current_user = nil, liquidation_order_id = nil, update_params = {})
      liquidation_order_id ||= id
      original_code, status_id = LookupStatusService.new('Liquidation', lot_status).call
      update_params.merge!({liquidation_order_id: liquidation_order_id, status_id: status_id, status: original_code})
      liquidations.each do |liquidation|
        liquidation.update!(update_params)
        details = current_user.present? ? { status_changed_by_user_id: current_user.id, status_changed_by_user_name: current_user.full_name } : {}
        LiquidationHistory.create(liquidation_id: liquidation.id, status_id: status_id, status: original_code, created_at: Time.now, updated_at: Time.now, details: details)
      end
    end

    # after_create :create_history
    # after_update :create_history, :if => Proc.new {|repair| repair.saved_change_to_status_id?}

    def create_history
        # status = LookupValue.find(status_id)
        # self.liquidation_order_histories.create(status: status.original_code, status_id: status_id, details: {"pending_closure_created_date" => Time.now.to_s } ) if status.original_code == "Pending Closure"
        # self.repair_histories.create(status_id: status_id, details: {"pending_repair_quotation_created_date" => Time.now.to_s } ) if status.original_code == "Pending Repair Quotation"
        # self.repair_histories.create(status_id: status_id, details: {"pending_repair_approval_created_date" => Time.now.to_s } ) if status.original_code == "Pending Repair Approval"
        # self.repair_histories.create(status_id: status_id, details: {"pending_repair_created_date" => Time.now.to_s } ) if status.original_code == "Pending Repair"
        # self.repair_histories.create(status_id: status_id, details: {"pending_repair_grade_created_date" => Time.now.to_s } ) if status.original_code == "Pending Repair Grade" 
        # self.repair_histories.create(status_id: status_id, details: {"pending_repair_disposition_created_date" => Time.now.to_s } ) if status.original_code == "Pending Repair Disposition" 
    end

    def quotation_by_priority
        return self.quotations.pluck(:expected_price).sort.reverse rescue nil
    end

    def self.update_existing_records
      self.all.each do |lo|
        if lo.vendor_quotation_links.present? || lo.winner_code.present?
          lo.details['email_sent'] = true
          lo.save
        end
      end
    end

    def is_expired?
      Time.now.in_time_zone('Mumbai').to_datetime.strftime("%d/%b/%Y - %I:%M %p").to_datetime > self.end_date_with_localtime.to_datetime.strftime("%d/%b/%Y - %I:%M %p").to_datetime rescue false
    end

    def update_lot_name_and_order_number
      org_name = created_by.organization_name rescue "OR-Liquidation"
      attrs = {
        lot_name: "#{lot_name.presence || ""} || #{parent_moq_order_id.to_s}",
        order_number: "#{org_name.presence || ""}-#{parent_moq_order_id.to_s}-#{SecureRandom.hex(6)}"
      }
      self.update!(attrs)
    end

    def self.generate_email_lot_billing
      liquidations = LiquidationOrder.includes(:liquidations, :quotations).where("lot_type = ? and start_date >= ? and end_date <= ? and status in (?)", "Email Lot", (1.month.ago.beginning_of_month), (1.month.ago.end_of_month), ["Dispatch Ready","Dispatched"])
      CSV.open("#{Rails.root}/public/#{(Time.now - 1.month).strftime("%B").downcase}_#{(Time.now - 1.month).strftime("%Y").downcase}_email_lots.csv", "wb") do |csv|
        csv << ["Lot ID", "Lot Name", "Winner Amount", "Total Bid Count", "Unique Bid Count",  "Quantity", "MRP",  "Start Date", "End Date", "Created At", "Status", "Tag Numbers"]
        liquidations.each do |liquidation|
          csv << [liquidation.id, liquidation.lot_name, liquidation.winner_amount, liquidation.quotations.size, liquidation.quotations.collect(&:vendor_master_id).uniq.size, liquidation.quantity, liquidation.mrp, (liquidation.start_date_with_localtime.strftime("%d-%m-%Y") rescue nil), (liquidation.end_date_with_localtime.strftime("%d-%m-%Y") rescue nil), liquidation.created_at.strftime("%d-%m-%Y"), liquidation.status, (liquidation.liquidations.collect(&:tag_number).join(", ") rescue nil)]
        end
      end
    end

    def self.generate_daily_dispatch_lots
      orders = LiquidationOrder.with_deleted.includes(:liquidations).where.not(status: ['Pending Publish']).where(end_date: ((Date.today.beginning_of_month.beginning_of_day)..(Time.zone.now.end_of_day - 6.hours)))
      file_csv = CSV.generate(headers: true) do |csv|
        csv <<  ["Created Date", "Lot ID",  "Lot Name", "Lot Type", "Lot Status", "Bid Start Date & Time", "Bid End Date & Time", "Floor Price/ Expected Price" ,"Number of Bids Received", "Highest Bid", "Highest Bidder Name", "Highest Bidder's Vendor Code", "Winner Amount", "Winner Name", "Winner Code", "Bidder 1 Name and Vendor Code", "Bidder 2 Name and Vendor Code", "Bidder 3 Name and Vendor Code", "Bidder 4 Name and Vendor Code", "Bidder 5 Name and Vendor Code", "Bidder 6 Name and Vendor Code", "Bidder 7 Name and Vendor Code", "Bidder 8 Name and Vendor Code", "Bidder 9 Name and Vendor Code", "Bidder 10 Name and Vendor Code"]
        orders.select {|o| ['Beam Lot', 'Email Lot', 'Contract Lot'].include?(o.lot_type) }.each do |lot|
          next if (lot.end_date_with_localtime.strftime("%d/%b/%Y - %I:%M %p").to_datetime > Time.now.strftime("%d/%b/%Y - %I:%M %p").to_datetime rescue true)
          if lot.lot_type == 'Beam Lot'
            bids_count = lot.bids.size
            highest_bid = lot.bids.pluck(:bid_price).max
            higest_bidder_name = lot.bids.order(bid_price: :desc).first(10).first.user_name  rescue ''
            higest_bidder_code = "NA"
            price = lot.floor_price
            higest_bids = lot.bids.order(bid_price: :desc).first(10).pluck(:user_name) rescue ''
            winner_name = lot.winner_code
          else
            bids_count = Quotation.where(liquidation_order_id: lot.id).size
            highest_bid = Quotation.where(liquidation_order_id: lot.id).pluck(:expected_price).max
            price = lot.order_amount
            higest_bids = Quotation.where(liquidation_order_id: lot.id).order(expected_price: :desc).first(10).map{|q| "#{q.vendor_master.vendor_name}/#{q.vendor_master.vendor_code}"} rescue ''
            higest_bidder_name = Quotation.where(liquidation_order_id: lot.id).order(expected_price: :desc).first(10).first.vendor_master.vendor_name rescue ''
            higest_bidder_code = Quotation.where(liquidation_order_id: lot.id).order(expected_price: :desc).first(10).first.vendor_master.vendor_code rescue ''
            winner_name = VendorMaster.find_by(vendor_code: lot.winner_code).vendor_name rescue 'NA'
          end
          csv << [lot.created_at.strftime("%F %I:%M:%S %p"), lot.id, lot.lot_name, lot.lot_type, lot.get_status, lot.start_date_with_localtime.strftime("%F %I:%M:%S %p"), lot.end_date_with_localtime.strftime("%F %I:%M:%S %p"), price, (bids_count.present? ? bids_count : 'No Bids'), (highest_bid.present? ? highest_bid : "No Bids"), (higest_bidder_name.present? ? higest_bidder_name : 'No Bids'), (higest_bidder_code.present? ? higest_bidder_code : "No Bids"), lot.winner_amount, winner_name, lot.winner_code, higest_bids].flatten
        end
      end
      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

      bucket = Rails.application.credentials.aws_bucket

      time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')

      file_name = "daily_auction_report_#{time.parameterize.underscore}"

      obj = amazon_s3.bucket(bucket).object("uploads/lot_inventory_report/#{file_name}.csv")

      obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')

      url = obj.public_url
      ReportMailer.lot_closer_email(url).deliver_now
    end


    def self.auto_assign_bid
      self.where("winner_code is NULL or winner_amount is NULL").where.not(status: ['Dispatched', 'Dispatch Ready', 'Partial Payment', 'No Bid', 'Full Payment', 'Pending Publish']).each do |i|
        if i.is_expired? || (i.status == 'Confirmation Pending')
          if i.lot_type  == 'Beam Lot'
            highest_bid = i.bids.order(bid_price: :desc).first
            if highest_bid.present?
              i.winner_code = highest_bid.user_name
              i.winner_amount = highest_bid.bid_price
              i.save
            end
          elsif i.lot_type == 'Email Lot'
            highest_bid = Quotation.where(liquidation_order_id: i.id).order(expected_price: :desc).first
            if highest_bid.present?
              i.winner_code = highest_bid.vendor_master.vendor_code
              i.winner_amount = highest_bid.expected_price
            end
            if i.is_expired? && i.details.present? && i.details['set_inventory_status'].present?
              i.details['set_inventory_status'] = false
              i.update_liquidation_status('create_bids')
            end
            i.save
          end
        end
      end
    end

    def get_status
      if deleted_at.present? || status == 'Archived'
        return 'Canceled'
      elsif (status == 'In Progress' || (status == 'Pending Closure') || status == 'Confirmation Pending' || status == 'No Bid')
        return 'Decision Pending'
      elsif warehouse_orders.present?
        status = LookupValue.find(warehouse_orders.last.status_id)
        return status.original_code
      end
    end

    def update_tags(liquidation_records = nil)
      liquidation_records ||= liquidations
      update(tags: liquidation_records.pluck(:tag_number))
    end

    def get_payment_status(payment_received)
      self.winner_amount > payment_received ? Rails.application.credentials.lot_status_partial_payment : Rails.application.credentials.lot_status_full_payment_received
    end

    def mrp
      self[:mrp] || bench_mark_price
    end

    def end_bid_and_take_decision(end_time: DateTime.now, send_callback: false)
      self.update(end_date: end_time)
      self.reload
      self.bids.reload
      higest_bid = self.bids.order(bid_price: :desc).first
      if higest_bid.present?
        highest_bid_price = higest_bid.bid_price.to_f
      else
        highest_bid_price = 0
      end

      if !is_moq_lot? && (highest_bid_price.to_f >= self.reserve_price.to_f)
        pending_payment_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_payment)
        self.update(winner_amount: highest_bid_price, winner_code: higest_bid.user_name, buyer_name: higest_bid.user_name, status: pending_payment_status.original_code, status_id: pending_payment_status.id)
        update_winner_details_to_beam(higest_bid) if send_callback
      else
        moq_sub_lot_pending_decision = LookupValue.find_by(code: Rails.application.credentials.lot_status_moq_sub_lot_pending_decision)
        pending_decision_status = if is_moq_lot?
          moq_sub_lot_in_progress_b2b = LookupValue.find_by(code: Rails.application.credentials.lot_status_moq_sub_lot_in_progress_b2b)
          moq_sub_lots.where(status: moq_sub_lot_in_progress_b2b.original_code).update_all(end_date: end_time, dispatch_ready: false, payment_status: moq_sub_lot_pending_decision.original_code, status: moq_sub_lot_pending_decision.original_code, status_id: moq_sub_lot_pending_decision.id)
          "lot_status_hide_for_pending_decision" unless moq_sub_lots.where(status: moq_sub_lot_pending_decision.original_code).any?
        end
        pending_decision_status = LookupValue.find_by(code: pending_decision_status || Rails.application.credentials.lot_status_pending_decision)
        self.update(status: pending_decision_status.original_code, status_id: pending_decision_status.id)
      end
      self.liquidation_order_histories.create(status: self.status, status_id: self.status_id)
    end

    def available_sub_lot
      sub_lot_pending_decision_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_moq_sub_lot_pending_decision).original_code
      sub_lot_in_progress_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_moq_sub_lot_in_progress_b2b).original_code
      sub_lot_publishing_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_publishing_sub_lot).original_code
      moq_sub_lots.where(status: [sub_lot_pending_decision_status, sub_lot_in_progress_status, sub_lot_publishing_status])
    end

    def approve_winner_details
      pending_payment_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_payment)
      self.update(status: pending_payment_status.original_code, status_id: pending_payment_status.id)
      assign_vendor_higest_bid = self.bids.where(user_name: self.buyer_name).order(bid_price: :desc).first
      update_winner_details_to_beam assign_vendor_higest_bid if assign_vendor_higest_bid.present?
    end

    def reject_winner_details
      old_buyer_details = self.details["old_buyer_details"]
      pending_decision_status = LookupValue.find_by(id: old_buyer_details["old_status_id"])
      self.update(status: pending_decision_status.original_code, status_id: pending_decision_status.id, winner_code: old_buyer_details['winner_code'], buyer_name: old_buyer_details['buyer_name'], winner_amount: old_buyer_details['winner_amount'])
    end

    ['start_date', 'end_date'].each do |method_name|
      define_method "#{method_name}=" do |value|
        self[method_name] = value.in_time_zone('Mumbai') rescue value
      end

      define_method "#{method_name}_with_localtime" do
        self[method_name].in_time_zone('Mumbai') rescue self[method_name]
      end
    end

    def parent_liquidation_order_id
      liquidation_order_id.presence || id
    end

    def parent_moq_order_id
      moq_order_id.presence || id
    end

    ['MOQ Lot', 'MOQ Sub Lot', 'B2C'].each do |method_name|
      define_method "is_#{method_name.parameterize.underscore}?" do
        lot_type == method_name
      end
    end

    def update_moq_lots_status(params)
      order_status = LookupValue.find_by(original_code: "Pending Payment")
      sub_lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_moq_sub_lot_in_progress_b2b)
      price_per_lot = moq_sub_lot_prices.find_by('? BETWEEN "from_lot" AND "to_lot"', params.dig(:buy_details, :quantity).to_i).try(:price_per_lot).to_i
      sub_lots_moq = moq_sub_lots.where(status: sub_lot_status.original_code).order(:lot_order).limit(params.dig(:buy_details, :quantity).to_i)
      sub_lots_moq.each do |sub_lot|
        details['sub_lot_quantity'].each do |raw_data|
          liquidations.where(sku_code: raw_data['article_id'], grade: raw_data['grade'], liquidation_order_id: id).limit(raw_data['lot_quantity'].to_i).update_all(
            lot_name: sub_lot.lot_name,
            liquidation_order_id: sub_lot.id,
            lot_type: sub_lot.lot_type,
            status: order_status.original_code,
            status_id: order_status.id,
            )
        end
        sub_lot.details.merge!({ beam_order_number: params.dig(:buy_details, :order_number) })
        sub_lot.update!(
          winner_code: params.dig(:user_details, :username),
          vendor_code: params.dig(:user_details, :username),
          buyer_name: params.dig(:user_details, :username),
          winner_amount: price_per_lot,
          amount_received: params.dig(:buy_details, :winner_amount_received),
          end_date: params.dig(:lot_details, :end_date),
          dispatch_ready: false,
          payment_status: order_status.original_code,
          status: order_status.original_code,
          status_id: order_status.id
          )
      end
      update_moq_lot_quantity(params.dig(:buy_details, :quantity).to_i, true)
      url = Rails.application.credentials.reseller_url + "/api/orders/update_sub_lot"
      payload = {
        order_number: params.dig(:buy_details, :order_number),
        lot_publish_id: params.dig(:lot_details, :lot_publish_id),
        sub_lot_ids: sub_lots_moq.pluck(:id)
      }
      RestClient::Request.execute(method: :post, url: url, payload: payload, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
    end

    def create_sub_lots_and_prices(moq_lot_params, current_user)
      moq_lot_params = moq_lot_params.with_indifferent_access
      moq_sub_lot_prices.create!(moq_lot_params[:lot_range].map{|lot_range| {from_lot: lot_range[:from_lot], to_lot: lot_range[:to_lot], price_per_lot: lot_range[:price_per_lot]}}) if moq_lot_params[:lot_range].present?
      moq_lot_params[:lot].delete(:maximum_lots_per_buyer)
      moq_lot_params[:lot].merge!({
        status: moq_lot_params[:sub_lot_status],
        status_id: moq_lot_params[:sub_lot_status_id],
        lot_type: moq_lot_params[:sub_lot_type],
        lot_type_id: moq_lot_params[:sub_lot_type_id]
      })
      (1..moq_lot_params[:possible_sub_lots].to_i).each do |lot_order|
        liquidations = []
        moq_lot_params[:sub_lot_quantity].each do |raw_data|
          liquidations += Liquidation.where(sku_code: raw_data[:article_id], grade: raw_data[:grade], status: 'MOQ Price').limit(raw_data[:lot_quantity].to_i)
        end
        moq_lot_params[:lot].merge!({
          mrp: liquidations.map(&:bench_mark_price).inject(:+),
          quantity: liquidations.count,
          moq_order_id: id,
          lot_order: lot_order
        })
        moq_lot_params.merge!({ liquidation_ids: liquidations.pluck(:id), parent_lot: self })
        LiquidationOrder.create_lot(moq_lot_params.with_indifferent_access, current_user)
      end
      moq_sub_lots.update_all(distribution_center_id: distribution_center_id)
      self.update!(mrp: moq_lot_params.dig(:lot, :mrp))
      self.assign_lot_category(self.liquidations) unless self.lot_category.present?
      self.update_tags(self.liquidations) unless self.tags.present?
    end

    def can_be_publish?
      return false unless start_date.present? && end_date.present? && lot_name.present? && lot_desc.present?
      if lot_type == "Competitive Lot"
        floor_price.present? && reserve_price.present? && buy_now_price.present?
      elsif lot_type == "MOQ Lot"
        details['sub_lot_quantity'].present? && moq_sub_lot_prices.present?
      end
    end

    def start_and_end_time_changed?
      previous_changes.present? && (previous_changes["start_date"].present? || previous_changes["end_date"].present?)
    end

    def self.move_dispatch_lot
      begin
        task_manager = TaskManager.create_task('LiquidationOrder.move_dispatch_lot')
        dispatch_lots =  LiquidationOrder.where(status: 'Full Payment Received').where("(details ->> 'dispatch_date' = :date OR details ->> 'tat_date' = :date) AND details ->> 'dispatch_status' IS NULL", date: Date.today.to_s).uniq
        dispatch_status = LookupValue.find_by(code: Rails.application.credentials.liquidation_pending_lot_dispatch_status)
        dispatch_lots.each do |lot|
          next unless lot.reload.details['dispatch_status'] == nil
          lot.create_dispatch_items
          lot.details['dispatch_status'] = 'completed'
          lot.update(status: dispatch_status.original_code, status_id: dispatch_status.id)
        end
        task_manager.complete_task
      rescue => exception
        task_manager.complete_task(exception)
      end
    end

    def create_dispatch_items
      warehouse_order = create_warehouse_order
      create_warehouse_order_items(warehouse_order)
    end

    def lot_status
      if status == 'In Progress B2B'
        'In Progress'
      elsif status == 'Pending Payment'
        'Payment Pending'
      else
        status
      end
    end

    def self.update_distribution_and_bench_marck_price
      self.includes(liquidations: :inventory).find_each do |lo|
        liquidations = lo.liquidations
        dis_id  = liquidations.last&.distribution_center_id
        benchmark_price = liquidations.map(&:bench_mark_price).inject(:+)
        lo.update_columns(distribution_center_id: dis_id, bench_mark_price: benchmark_price)
      end
    end

    def self.auto_publish_lots
      lot_in_progress_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_in_progress_b2b)

      all.publishable_lots.each do |lot|
        next unless lot.reload.republish_status == nil
        begin
          user = User.find_by(id: lot.created_by_id)
          response = lot.publish(user)
          api_response = unless response
            { republish_status: 'pending', beam_lot_response: nil }
          else
            { republish_status: 'error', beam_lot_response: response }
          end
          lot.update!(api_response)
        rescue Exception => e
          Rails.logger.error(e.to_s)
          next
        end
      end

      all.republishable_lots.each do |lot|
        next unless lot.reload.republish_status == 'republishing'
        begin
          user = User.find_by(id: lot.created_by_id)
          response = lot.republish_to_reseller(user)
          api_response = if (response.code != 200 || response.blank?)
            { republish_status: 'error', beam_lot_response: JSON.parse(response) }
          else
            if lot.is_moq_lot?
              sub_lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_moq_sub_lot_in_progress_b2b)
              lot.moq_sub_lots.update_all(status: sub_lot_status.original_code, status_id: sub_lot_status.id)
            else
              lot.bids.update_all(is_active: false)
            end
            { republish_status: 'success', beam_lot_id: JSON.parse(response)['lot_publish_id'], status: lot_in_progress_status.original_code, status_id: lot_in_progress_status.id }
          end

          lot.update!(api_response)
        rescue Exception => e
          Rails.logger.error(e.to_s)
          next
        end
      end
    end

    private

    def create_warehouse_order
      warehouse_orders.create( 
        orderable:  self,
        vendor_code: winner_code,
        total_quantity:  liquidations.count,
        client_id: liquidations.last&.client_id,
        reference_number: order_number,
        distribution_center_id: liquidations.first&.distribution_center_id, 
        status_id: LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick).id
      )
    end

    def create_warehouse_order_items(warehouse_order)
      warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick)
      liquidations.each do |liquidation_item|
        liquidation_item.update(status: warehouse_order_status.original_code, status_id: warehouse_order_status.id)
        details = { "#{liquidation_item.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now}
        liquidation_item.liquidation_histories.create(status_id: liquidation_item.status_id, details: details)

        client_sku_master = ClientSkuMaster.find_by_code(liquidation_item.sku_code)  rescue nil
        client_category = client_sku_master.client_category rescue nil
        warehouse_order.warehouse_order_items.create(
          inventory_id: liquidation_item.inventory_id,
          client_category_id: client_category.try(:id),
          client_category_name: client_category.try(:name),
          sku_master_code: client_sku_master.try(:code),
          item_description: liquidation_item.item_description,
          tag_number: liquidation_item.tag_number,
          serial_number: liquidation_item.inventory.serial_number,
          quantity: liquidation_item.sales_price,
          status_id: warehouse_order_status.id,
          status: warehouse_order_status.original_code
        )
      end
    end

    def update_higest_bid
      lot_status_confirmation_pending = LookupValue.find_by(code: Rails.application.credentials.lot_status_confirmation_pending)
      if self.status_id_changed? && (self.status_id == lot_status_confirmation_pending.try(:id))
        higest_bid = self.bids.order(bid_price: :desc).first rescue nil
        if higest_bid.present?
          self.winner_amount = higest_bid.bid_price
          self.winner_code = higest_bid.user_name
          update_winner_details_to_beam higest_bid
        end
      end
    end

    def update_winner_details_to_beam winner_bid
      if self.beam_lot_id.present?
        url = Rails.application.credentials.reseller_url + "/api/lot_winner_details/update_winner_details"
        payload = {
          lot_publish_id: beam_lot_id,
          winner_id: winner_bid.buyer_id,
          winner_bid_id: winner_bid.beam_bid_id,
          winner_bid_amount: self.winner_amount
        }
        RestClient::Request.execute(method: :patch, url: url, payload: payload, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
      end
    end

    def update_status_to_beam
      if self.beam_lot_id.present? && !is_moq_lot?
        url = Rails.application.credentials.reseller_url+"/api/lot_publishes/#{ self.beam_lot_id }/update_lot_status"
        RestClient::Request.execute(method: :patch, url: url, payload: { lot_status: self.lot_status, order_number: self.details['beam_order_number'], lot_id: self.id }, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
      end
    end

    def extend_time_to_reseller
      if self.beam_lot_id.present?
        url = Rails.application.credentials.reseller_url+"/api/lot_publishes/#{self.beam_lot_id}/extend_bid_time"
        RestClient::Request.execute(method: :patch, url: url, payload: {start_date: self.start_date, end_date: self.end_date}, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
      end
    end

    def update_pending_publish_status
      publish_status = if republish_status == 'error'
        LookupValue.find_by(code: Rails.application.credentials.lot_status_publish_error)
      elsif republish_status == 'pending'
        LookupValue.find_by(code: Rails.application.credentials.lot_status_publish_initiated)
      elsif republish_status == 'republishing' && can_be_publish?
        LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_republishing)
      else
        can_be_publish? ? LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_publishing) : LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_lot_details)
      end
      self.update(status: publish_status.original_code, status_id: publish_status.id) unless self.status == publish_status.original_code
    end

    def set_distribution_center_id
      return if distribution_center_id.present?
      liquidation = self.reload.liquidations.last
      self.distribution_center_id = liquidation.distribution_center_id if liquidation.present?
    end
  
    def update_bench_mark_price
      return if bench_mark_price.present?
      self.bench_mark_price = liquidations.map(&:bench_mark_price).inject(:+) if liquidations.present?
    end
end
