---
name: generate-resource
description: Generate a new Rails resource following 37signals conventions
args:
  - name: resource_name
    description: Name of the resource (singular, e.g., "card")
    required: true
---

# Generate Resource: $ARGUMENTS

Create a new Rails resource following 37signals conventions.

## 1. Plan the Resource

Before generating, consider:
- What's the resource name? (singular: `card`, plural: `cards`)
- What associations does it have?
- What behavior does it need? (Closeable? Watchable?)
- What's the REST interface?

## 2. Generate Migration

```bash
rails generate migration Create{{ResourceName}}s
```

Edit the migration to use UUIDv7 primary keys with database-level default:

```ruby
class Create{{ResourceName}}s < ActiveRecord::Migration[8.0]
  def change
    create_table :{{resource_name}}s, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
      # Add columns here
      t.string :title, null: false
      t.text :description

      # Foreign keys with UUIDv7 (string type)
      t.references :board, null: false, foreign_key: true, type: :string
      t.references :author, null: false, foreign_key: { to_table: :users }, type: :string

      t.timestamps
    end

    # Add indexes for common queries
    add_index :{{resource_name}}s, [:board_id, :created_at]
  end
end
```

## 3. Create Model

```ruby
# app/models/{{resource_name}}.rb
class {{ResourceName}} < ApplicationRecord
  # Associations
  belongs_to :board
  belongs_to :author, class_name: "User"

  # Include concerns for shared behavior
  # include Closeable
  # include Watchable

  # Validations (prefer database constraints)
  validates :title, presence: true

  # Scopes
  scope :chronologically, -> { order(created_at: :asc) }
  scope :reverse_chronologically, -> { order(created_at: :desc) }
  scope :preloaded, -> { includes(:board, :author) }
end
```

## 4. Create Controller

```ruby
# app/controllers/{{resource_name}}s_controller.rb
class {{ResourceName}}sController < ApplicationController
  before_action :set_{{resource_name}}, only: [:show, :edit, :update, :destroy]

  def index
    @{{resource_name}}s = {{ResourceName}}.preloaded.reverse_chronologically
  end

  def show
  end

  def new
    @{{resource_name}} = {{ResourceName}}.new
  end

  def create
    @{{resource_name}} = Current.user.{{resource_name}}s.build({{resource_name}}_params)

    if @{{resource_name}}.save
      redirect_to @{{resource_name}}, notice: "{{ResourceName}} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @{{resource_name}}.update({{resource_name}}_params)
      redirect_to @{{resource_name}}, notice: "{{ResourceName}} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @{{resource_name}}.destroy
    redirect_to {{resource_name}}s_path, notice: "{{ResourceName}} deleted."
  end

  private

  def set_{{resource_name}}
    @{{resource_name}} = {{ResourceName}}.find(params[:id])
  end

  def {{resource_name}}_params
    params.require(:{{resource_name}}).permit(:title, :description, :board_id)
  end
end
```

## 5. Add Routes

```ruby
# config/routes.rb
resources :{{resource_name}}s
```

## 6. Create Views

Create basic views in `app/views/{{resource_name}}s/`:
- `index.html.erb`
- `show.html.erb`
- `new.html.erb`
- `edit.html.erb`
- `_form.html.erb`
- `_{{resource_name}}.html.erb` (partial)

## 7. Create Fixtures

```yaml
# test/fixtures/{{resource_name}}s.yml
one:
  id: 01961a2a-c0de-7000-8000-000000000001
  board: main
  author: admin
  title: First {{ResourceName}}

two:
  id: 01961a2a-c0de-7000-8000-000000000002
  board: main
  author: admin
  title: Second {{ResourceName}}
```

## 8. Create Tests

```ruby
# test/models/{{resource_name}}_test.rb
class {{ResourceName}}Test < ActiveSupport::TestCase
  test "belongs to board" do
    assert_equal boards(:main), {{resource_name}}s(:one).board
  end

  test "requires title" do
    {{resource_name}} = {{ResourceName}}.new
    assert_not {{resource_name}}.valid?
    assert_includes {{resource_name}}.errors[:title], "can't be blank"
  end
end
```

## 9. Run Migrations and Tests

```bash
rails db:migrate
rails test
bundle exec rubocop -A
```