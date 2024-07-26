class OutboundReportMailerWorker
  include Sidekiq::Worker

  def perform(type, user_id, start_date=nil, end_date=nil, email=nil, outbound_receiving_sites, outbound_supplying_sites)
    user = User.find_by_id(user_id)
    url = OutboundDocument.generate_outbound_doc_report(user, start_date, end_date, outbound_receiving_sites, outbound_supplying_sites) if type == 'outbound_documents'
    time = Time.now.in_time_zone('Mumbai').strftime("%d/%b/%Y - %I:%M %p")
    ReportMailer.outbound_documents_email(type ,url, user_id, email, time).deliver_now
  end
end