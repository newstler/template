# Rails 8 Template

A modern Rails 8 template following 37signals' vanilla Rails philosophy with built-in magic link authentication.

## Tech Stack

- **Ruby** 4.0.x
- **Rails** 8.2.x
- **Database**: SQLite with Solid Stack (Cache, Queue, Cable)
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS 4
- **Asset Pipeline**: Propshaft
- **Deployment**: Kamal 2
- **Authentication**: Magic Links (passwordless)
- **Admin Panel**: Avo 3.x
- **Primary Keys**: ULIDs (sortable, distributed-friendly)

## Features

- **Magic Link Authentication** for users and admins
  - Users: First magic link creates account, subsequent ones sign in
  - Admins: Only existing admins can create new admins
- **ULID Primary Keys** for better distributed system support
- **Solid Stack** for production-ready background jobs, caching, and cable
- **Vanilla Rails** approach - no unnecessary abstractions

## Getting Started

### Clone for a New Project

```bash
# Clone this template
git clone git@github.com:newstler/template.git my_new_project
cd my_new_project

# Keep template as remote for updates
git remote rename origin template
git remote add origin git@github.com:yourname/my_new_project.git

# Configure project (renames from Template, sets admin email)
bin/configure

# This will prompt you for:
#   - Project name (defaults to folder name)
#   - Admin email address
# Then it will automatically run bin/setup
```

The `bin/configure` script will:
1. Rename the project from "Template" to your project name
2. Ask for your admin email
3. Create `.env` file with admin email
4. Update `db/seeds.rb` to use the email
5. Run `bin/setup` to install dependencies and setup database

### Pull Template Updates

```bash
# Pull latest changes from template
git fetch template
git merge template/main

# Or cherry-pick specific commits
git cherry-pick <commit-hash>
```

## Authentication System

### User Authentication

Users can sign up and sign in using magic links sent to their email:

1. Visit `/session/new`
2. Enter email address
3. Receive magic link via email (creates account on first use)
4. Click link to sign in

### Admin Authentication

Admins must be created by other admins:

1. First admin is created via `rails db:seed` (update email in `db/seeds.rb`)
2. Existing admins can create new admins at `/admins/admins`
3. New admin receives magic link via email
4. Admin signs in at `/admins/session/new`

### Admin Access

- Admin panel: `/avo`
- Admin management: `/admins/admins`
- Admin login: `/admins/session/new`

Only authenticated admins can access Avo.

## Development

```bash
# Start dev server (Procfile.dev)
bin/dev

# Console
rails console

# Database
rails db
rails db:migrate
rails db:seed

# Tests
rails test
rails test test/models/user_test.rb:42

# Code quality
bundle exec rubocop -A

# Reconfigure project (if needed)
bin/configure
```

### Environment Variables

The project uses `.env` for development configuration:

```bash
FIRST_ADMIN_EMAIL=admin@example.com
```

This is automatically created by `bin/configure`.

## Architecture Principles

This template follows [37signals vanilla Rails philosophy](https://dev.37signals.com/) and patterns from [Layered Design for Ruby on Rails Applications](https://www.packtpub.com/product/layered-design-for-ruby-on-rails-applications/9781801813785):

- **Rich domain models** over service objects
- **CRUD controllers** - everything is a resource
- **Concerns** for horizontal code sharing
- **Grow into abstractions** - don't create empty directories
- **Ship to learn** - prototype quality is valid

See [CLAUDE.md](./CLAUDE.md) for complete guidelines.

## Project Structure

```
app/
├── controllers/
│   ├── sessions_controller.rb        # User auth
│   └── admins/
│       ├── sessions_controller.rb    # Admin auth
│       └── admins_controller.rb      # Admin management
├── models/
│   ├── user.rb                       # User model
│   └── admin.rb                      # Admin model
├── mailers/
│   ├── user_mailer.rb                # User magic links
│   └── admin_mailer.rb               # Admin magic links
└── views/
```

## Deployment

Using Kamal 2:

```bash
# Update config/deploy.yml with your settings
kamal setup
kamal deploy
```

See `config/deploy.yml` for configuration.

## Credentials

```bash
# Edit credentials
rails credentials:edit --environment development
rails credentials:edit --environment production
```

Example structure:

```yaml
# Stripe, OpenAI, Anthropic, etc.
stripe:
  secret_key: sk_test_...
  webhook_secret: whsec_...
```

## License

MIT

## Credits

Built by [Yuri Sidorov](https://yurisidorov.com) following best practices from:
- [37signals](https://37signals.com/)
- [Layered Design for Ruby on Rails Applications](https://www.packtpub.com/product/layered-design-for-ruby-on-rails-applications/9781801813785)
