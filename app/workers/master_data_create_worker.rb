class MasterDataCreateWorker

  include Sidekiq::Worker

  def perform(master_data_id, type)
    master_data = MasterDataInput.where("id = ?", master_data_id).first
    master_data.update(status: "In Progress")
    case type
    when 'SKU'
      ClientSkuMaster.create_master_data(master_data_id)
    when 'GatePass'
      GatePass.create_master_data(master_data_id)
    when 'OutboundDocument'
      OutboundDocument.create_master_data(master_data_id)
    when 'OutboundRTNDocument'
      OutboundDocument.create_rtn_master_data(master_data_id)
    when 'GI'
      GatePass.create_gi_master_data(master_data_id)
    when 'Vendor'
      VendorMaster.create_master_data(master_data_id)
    when 'DC'
      DistributionCenter.create_master_data(master_data_id)
    when 'ExpArticleScanIndicator'
      ExceptionalArticle.create_article_scan_ind_mapping(master_data_id)
    when 'ExpArticleSerialNumber'
      ExceptionalArticleSerialNumber.create_article_sr_no_mapping(master_data_id)
    end
  end
end
