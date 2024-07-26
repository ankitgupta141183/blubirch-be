# frozen_string_literal: true

module Api
  module V1
    # Scan Inventory is used for Scanning and storing scanned invetories
    class ScanInventoriesController < ApplicationController
      def show
        scans = ScanInventory.where(tag_number: params[:tag_number])
        scans = scans.find_by(physical_inspection_id: params[:id]) if params[:id].present?
        render json: { message: 'success', is_scanned: scans.present?, scanned: scans }
      end
    end
  end
end
