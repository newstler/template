module Madmin
  class MailController < Madmin::ApplicationController
    def show
      @setting = Setting.instance
    end

    def edit
      @setting = Setting.instance
    end

    def update
      @setting = Setting.instance

      if @setting.update(mail_params)
        redirect_to main_app.madmin_mail_path, notice: t("controllers.madmin.mail.update.notice")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def mail_params
      params.require(:setting).permit(:mail_from, :smtp_address, :smtp_username, :smtp_password)
    end
  end
end
