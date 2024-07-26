class InboundReportMailerWorker
  include Sidekiq::Worker

  def perform(type, user_id, start_date=nil, end_date=nil, email=nil, inbound_receiving_sites, inbound_supplying_sites)
    user = User.find_by_id(user_id)
    url = GatePass.generate_inbound_doc_report(user, start_date, end_date, inbound_receiving_sites, inbound_supplying_sites) if type == 'inbound_documents'
    time = Time.now.in_time_zone('Mumbai').strftime("%d/%b/%Y - %I:%M %p")
    ReportMailer.inbound_documents_email(type ,url, user_id, email, time).deliver_now
  end
end