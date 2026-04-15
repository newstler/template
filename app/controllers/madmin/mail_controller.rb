module Madmin
  class MailController < Madmin::ApplicationController
    def show
      @setting = Setting.instance
    end

    def update
      @setting = Setting.instance

      if @setting.update(mail_params)
        respond_to do |format|
          format.json { head :ok }
          format.html { redirect_to main_app.madmin_mail_path, notice: t("controllers.madmin.mail.update.notice") }
        end
      else
        respond_to do |format|
          format.json { head :unprocessable_entity }
          format.html { redirect_to main_app.madmin_mail_path, alert: @setting.errors.full_messages.join(", ") }
        end
      end
    end

    private

    def mail_params
      params.require(:setting).permit(:mail_from, :smtp_address, :smtp_username, :smtp_password, :conversation_digest_window_minutes)
    end
  end
end
