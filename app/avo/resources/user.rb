class Avo::Resources::User < Avo::BaseResource
  self.title = :email
  self.includes = [:chats]

  self.search = {
    query: -> { query.where("email LIKE ? OR name LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id, readonly: true
    field :email, as: :gravatar, link_to_record: true
    field :name, as: :text, required: true
    field :email, as: :text, required: true, help: "User email address"

    field :chats, as: :has_many

    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter Avo::Filters::CreatedAtFilter
  end
end
