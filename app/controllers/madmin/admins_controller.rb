module Madmin
  class AdminsController < Madmin::ResourceController
    def show
      @record = Admin.find(params[:id])
    end

    def update
      @record = Admin.find(params[:id])
      if @record.update(admin_params)
        respond_to do |format|
          format.json { head :ok }
          format.html { redirect_to madmin_admin_path(@record), notice: t("controllers.madmin.admins.update.notice") }
        end
      else
        respond_to do |format|
          format.json { head :unprocessable_entity }
          format.html { redirect_to madmin_admin_path(@record) }
        end
      end
    end

    def send_magic_link
      @record = Admin.find(params[:id])
      AdminMailer.magic_link(@record).deliver_later
      redirect_to madmin_admin_path(@record), notice: t("controllers.madmin.admins.send_magic_link.notice", email: @record.email)
    end

    private

    def admin_params
      params.require(:admin).permit(:email, :locale)
    end
  end
end
