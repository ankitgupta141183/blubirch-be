class PrdMailer < ApplicationMailer

  def send_prd_items(csv, filename, subject, email_ids)
    attachments[filename] = {mime_type: 'text/csv', content: csv}

    mail(to: email_ids.uniq, subject: subject)
  end
end
