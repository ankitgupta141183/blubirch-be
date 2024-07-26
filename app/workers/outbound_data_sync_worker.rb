class OutboundDataSyncWorker

  include Sidekiq::Worker

  def perform(forward_sync_request_id)

    forward_sync_request = ForwardSyncedRequest.where("id = ?", forward_sync_request_id).first
        
    begin
      ForwardSyncedRequest.create_outbound_scanned_inventory(forward_sync_request.id)
    rescue => e
     Rails.logger.warn "----- Error in processing #{forward_sync_request.document_number} -- #{e.inspect}"
      forward_sync_request.update(status: "Error Processing Document")
    end 
    
  end

end
