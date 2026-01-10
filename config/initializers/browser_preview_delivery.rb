# Custom delivery method that opens emails in the browser automatically
class BrowserPreviewDelivery
  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    # Create tmp directory if it doesn't exist
    tmp_dir = Rails.root.join("tmp", "mails")
    FileUtils.mkdir_p(tmp_dir)

    # Generate a unique filename
    filename = "#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{mail.subject&.parameterize || 'mail'}.html"
    filepath = tmp_dir.join(filename)

    # Write the email HTML to file
    File.write(filepath, mail.html_part&.body || mail.body)

    # Open in browser
    system("open", filepath.to_s)

    Rails.logger.info "Email opened in browser: #{filepath}"
  end
end

# Register the delivery method
ActionMailer::Base.add_delivery_method :browser_preview, BrowserPreviewDelivery
