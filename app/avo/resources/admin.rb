class Avo::Resources::Admin < Avo::BaseResource
  self.title = :email
  self.includes = []

  self.search = {
    query: -> { query.where("email LIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id, readonly: true
    field :email, as: :gravatar, link_to_record: true
    field :email, as: :text, required: true, help: "Admin email address"
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def actions
    action Avo::Actions::SendAdminMagicLink
  end
end
