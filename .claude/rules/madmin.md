---
description: Madmin admin panel conventions
globs: ["app/madmin/**/*.rb", "app/controllers/madmin/**/*.rb"]
---

# Madmin Standards

## Overview

Madmin is the admin panel at `/madmin`. All admin CRUD operations go through Madmin resources.

## Creating Resources

```bash
rails generate madmin:resource ModelName
```

This creates `app/madmin/resources/model_name_resource.rb`

## Resource Configuration

```ruby
# app/madmin/resources/user_resource.rb
class UserResource < Madmin::Resource
  # Attributes displayed in admin
  attribute :id, form: false
  attribute :email
  attribute :name
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Customize index columns
  def self.index_attributes
    [:id, :email, :name, :created_at]
  end

  # Customize form fields
  def self.form_attributes
    [:email, :name]
  end

  # Customize show page
  def self.show_attributes
    [:id, :email, :name, :created_at, :updated_at]
  end

  # Scopes for filtering
  def self.scopes
    [
      Madmin::Scope.new(:all),
      Madmin::Scope.new(:recent, ->(resources) { resources.where("created_at > ?", 1.week.ago) })
    ]
  end
end
```

## Custom Fields

Create custom fields in `app/madmin/fields/`:

```ruby
# app/madmin/fields/json_field.rb
class JsonField < Madmin::Field
  def to_s
    JSON.pretty_generate(value) if value.present?
  end
end
```

Usage:
```ruby
attribute :metadata, field: "JsonField"
```

## Custom Actions

Add member actions to resources:

```ruby
class AdminResource < Madmin::Resource
  member_action :send_magic_link, method: :post do
    admin = Admin.find(params[:id])
    AdminMailer.magic_link(admin).deliver_later
    redirect_to madmin_admin_path(admin), notice: "Magic link sent!"
  end
end
```

## Authentication

```ruby
# app/controllers/madmin/application_controller.rb
class Madmin::ApplicationController < Madmin::BaseController
  before_action :authenticate_admin!

  private

  def authenticate_admin!
    redirect_to main_app.new_admins_session_path unless current_admin
  end

  def current_admin
    @current_admin ||= Admin.find_by(id: session[:admin_id]) if session[:admin_id]
  end
  helper_method :current_admin
end
```

## Customizing Views

Generate views to customize:

```bash
rails generate madmin:views
rails generate madmin:views users  # For specific resource
```

Views go in `app/views/madmin/`

## Interface Separation

**IMPORTANT:** Keep admin and user interfaces completely separate:
- User interface: `/session/new`, `/home`, etc.
- Admin interface: `/admins/session/new` (login), `/madmin` (panel)
- **No links between user and admin interfaces**
- Admin login is separate (different URLs, different styling)
