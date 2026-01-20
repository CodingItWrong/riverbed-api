# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Riverbed API is a Rails 8 backend for an iOS app that allows users to create interactive CRUD apps with no programming. It uses JSON:API format for most endpoints and provides OAuth2 authentication via Doorkeeper.

## Development Commands

### Setup
```bash
bundle install
rails db:setup
```

### Testing
```bash
# Run all tests
bin/rspec

# Run a single test file
bin/rspec spec/requests/boards_spec.rb

# Run a specific test
bin/rspec spec/requests/boards_spec.rb:10
```

### Static Checks
After any code changes, run:
```bash
# Run full test suite and fix any failures
bin/rspec

# Fix formatting issues
standardrb --fix
```

### Running the Server
```bash
bin/serve
```

### Code Generation
```bash
# Generate model
rails generate model widget [fields]

# Generate JSON:API resource
rails generate jsonapi:resource widget

# Generate JSON:API controller
rails generate jsonapi:controller widget
```

## Architecture

### JSON:API Pattern

The API follows the JSON:API specification using the `jsonapi-resources` gem. The architecture has three layers:

1. **Controllers** (`app/controllers/*_controller.rb`): Inherit from `JsonapiController`, which includes `JSONAPI::ActsAsResourceController`. Most controllers only need to call `doorkeeper_authorize!` for authentication.

2. **Resources** (`app/resources/*_resource.rb`): Inherit from `ApplicationResource` (which extends `JSONAPI::Resource`). Resources define:
   - Exposed attributes (with snake_case → kebab-case transformation)
   - Delegated attributes (e.g., `options` delegates to `board_options`)
   - Relationships to other resources
   - Creatable/updatable field restrictions
   - Scoping logic (e.g., `records` method filters by current user)
   - Lifecycle hooks (`before_create`, `after_create`, etc.)

3. **Models** (`app/models/*.rb`): Standard ActiveRecord models with associations and validations.

### Authentication & Authorization

- **OAuth2**: Implemented via Doorkeeper gem (`use_doorkeeper` in routes)
- **Token endpoint**: `POST /oauth/token` (non-JSON:API endpoint using `application/json`)
- **Authorization**: All JSON:API endpoints require Bearer token except user signup
- **User scoping**: Resources implement `self.records` method to scope queries to `current_user`
- **Current user access**: Available in resources via `current_user` method (from context)

### Key Architectural Patterns

**Attribute Delegation**: Resources can delegate to differently named model attributes:
```ruby
attribute :options, delegate: :board_options
attribute :icon_extended, delegate: :icon
```

**User Association**: All resources automatically associate with current user:
```ruby
before_create do
  _model.user = current_user
end
```

**Field Restrictions**: Remove user field from creatable/updatable fields to prevent user tampering:
```ruby
def self.creatable_fields(_context) = super - [:user]
def self.updatable_fields(_context) = super - [:user]
```

**Side Effects**: Use `after_create` hooks for creating related default data (e.g., boards create default column and card).

### Data Model

Core entities (all belong to User):
- **Board**: Top-level container for a custom app
  - Has many: Cards, Columns, Elements
  - Attributes: name, icon, color_theme, favorited_at, board_options (JSONB)
- **Card**: Data record on a board
  - Attributes: field_values (JSONB)
- **Column**: View/filter of cards
  - Attributes: name, display_order, sort_order, card_inclusion_conditions, card_grouping, summary (all JSONB)
- **Element**: Field definition for cards
  - Attributes: name, element_type, data_type, display_order, element_options, show_conditions (JSONB), show_in_summary, read_only, initial_value
- **User**: Account owner
  - Attributes: email, password_digest, ios_share_board_id, allow_emails

Cascade deletes: Deleting a user cascades to all their boards, cards, columns, elements.

### Testing Patterns

Request specs (`spec/requests/*_spec.rb`) follow a comprehensive pattern documented in `docs/API_ENDPOINT_MIGRATION_PLAN.md`. See [spec/requests/boards_spec.rb](spec/requests/boards_spec.rb) for the reference implementation.

Key testing requirements:
- Test all CRUD operations (success and failure)
- Test authentication (logged out returns 401 with empty body)
- Test authorization (users can't access other users' resources, returns 404)
- Validate complete JSON:API format compliance (`Content-Type: application/vnd.api+json`, `data`/`errors` structure)
- Test all resource attributes (reading, creating, updating)
- Test error handling (invalid JSON, missing/wrong type, ID mismatch)
- Verify side effects (e.g., board creation → default column/card)

Test helpers:
- Use `include_context "with a logged in user"` for authenticated tests
- Creates `user`, `token`, and `headers` with Bearer token and JSON:API content type
- Use FactoryBot factories for test data creation

### Non-JSON:API Endpoints

Two endpoints use standard JSON format:
1. **OAuth token**: `POST /oauth/token` - uses `application/json`, handled by Doorkeeper
2. **Share webhook**: `POST /shares` - uses `application/json`, handled by `SharesController`

## Migration Status

The project is actively migrating JSON:API endpoints. See [docs/API_ENDPOINT_MIGRATION_PLAN.md](docs/API_ENDPOINT_MIGRATION_PLAN.md) for progress.

Completed:
- Boards (4 endpoints)

Remaining:
- Users (4 endpoints)
- Columns (4 endpoints)
- Elements (4 endpoints)
- Cards (5 endpoints)

## Technology Stack

- Rails 8.0.3
- Ruby 3.4.4
- PostgreSQL (required)
- Gems:
  - `jsonapi-resources` - JSON:API implementation
  - `doorkeeper` - OAuth2 provider
  - `bcrypt` - Password hashing
  - `rack-cors` - CORS handling
  - `httparty` - Webhook HTTP client
  - `standard` - Ruby linting/formatting
  - `rspec-rails` - Testing framework
  - `factory_bot_rails` - Test data factories
