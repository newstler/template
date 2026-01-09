class Admins::AdminsController < ApplicationController
  before_action :authenticate_admin!

  def index
    @admins = Admin.all.order(created_at: :desc)
  end

  def new
    @admin = Admin.new
  end

  def create
    @admin = Admin.new(admin_params)

    if @admin.save
      # Send magic link to new admin
      AdminMailer.magic_link(@admin).deliver_later
      redirect_to admins_admins_path, notice: "Admin created and magic link sent!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @admin = Admin.find(params[:id])
    @admin.destroy
    redirect_to admins_admins_path, notice: "Admin deleted successfully"
  end

  private

  def admin_params
    params.expect(admin: [ :email ])
  end
end
