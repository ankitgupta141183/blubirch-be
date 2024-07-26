class ReportMailerWorker
  include Sidekiq::Worker

  def perform(type, user_id, start_date=nil, end_date=nil, email=nil, ids=nil)
    user = User.find_by_id(user_id)
    url = Inventory.export_inward_visibility_report(user) if type == 'visiblity'
    url = Inventory.export_outward_visibility_report(user) if type == 'outward'
    url = Inventory.timeline_report(user) if type == 'inward'
    url = Liquidation.export(user_id, ids) if type == 'liquidation_download'
    time = Time.now.in_time_zone('Mumbai').strftime("%d/%b/%Y - %I:%M %p")
    ReportMailer.visiblity_email(type ,url, user_id, email, time).deliver_now
  end
end