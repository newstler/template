module Madmin
  class AdminsController < Madmin::ResourceController
    def send_magic_link
      @record = Admin.find(params[:id])
      AdminMailer.magic_link(@record).deliver_later
      redirect_to madmin_admin_path(@record), notice: "Magic link sent to #{@record.email}!"
    end
  end
end
