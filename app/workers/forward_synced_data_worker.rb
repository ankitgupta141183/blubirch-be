class ForwardSyncedDataWorker

  include Sidekiq::Worker

  def perform(forward_sync_request_id)

    forward_sync_request = ForwardSyncedRequest.where("id = ?", forward_sync_request_id).first
        
    begin
      ForwardSyncedRequest.create_forward_scanned_inventory(forward_sync_request.id)
    rescue => e
     puts "----- Error in processing #{forward_sync_request.document_number} -- #{e.inspect}"
      forward_sync_request.update(status: "Error Processing Document")
    end 
    
  end

end
