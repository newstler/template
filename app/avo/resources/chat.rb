class Avo::Resources::Chat < Avo::BaseResource
  self.title = :id
  self.includes = [:user, :model, :messages]

  self.search = {
    query: -> { query.joins(:user).where("users.email LIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id, readonly: true

    field :user, as: :belongs_to, searchable: true
    field :model, as: :belongs_to, searchable: true, help: "AI model used for this chat"

    field :messages, as: :has_many

    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter Avo::Filters::CreatedAtFilter
  end
end
