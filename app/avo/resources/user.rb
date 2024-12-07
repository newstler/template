class Avo::Resources::User < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :email, as: :gravatar
    field :name, as: :text
    field :email, as: :text
    field :created_at, as: :date, readonly: true
    field :updated_at, as: :date, readonly: true
    field :id, as: :text, readonly: true
  end
end
