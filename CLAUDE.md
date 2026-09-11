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
```

JSON:API serialization is hand-written (see Architecture below) — there are no resource or
controller generators for it. Add a new endpoint by writing a controller that inherits from
`JsonapiController`.

## Architecture

### JSON:API Pattern

The API follows the JSON:API specification, **hand-written — there is no JSON:API gem**. The
project previously used `jsonapi-resources` and was migrated off it; there is no
`app/resources/` directory and no `jsonapi-resources` in the Gemfile. The architecture has
two layers:

1. **Controllers** (`app/controllers/*_controller.rb`): Inherit from `JsonapiController`
   (`app/controllers/jsonapi_controller.rb`), which provides the shared JSON:API plumbing:
   - `jsonapi_content_type` — the `application/vnd.api+json` content type, passed explicitly
     to every `render`
   - `validate_jsonapi_request(type, require_id:, expected_id:)` — parses the body and
     returns `:error` after rendering a 400 for invalid JSON, a missing `data` key, a
     missing/wrong `type`, or an ID mismatch. Returns `{attributes:, relationships:}` on
     success.
   - `render_not_found` — the 404 body used for both missing and unowned records
   - `render_validation_errors(record)` — maps validation errors to 422 JSON:API error objects

   Each controller then does its own scoping, attribute mapping, and serialization: a private
   `serialize_<resource>` method builds the resource object (`type`, `id`, `attributes`) with
   literal kebab-case attribute keys. Every action starts with `doorkeeper_authorize!`.

2. **Models** (`app/models/*.rb`): Standard ActiveRecord models with associations and
   validations.

Because serialization is per-controller, **the envelope is not automatically consistent across
resources** — when changing shared behavior, check each controller and its request spec.

### Authentication & Authorization

- **OAuth2**: Implemented via Doorkeeper gem (`use_doorkeeper` in routes)
- **Token endpoint**: `POST /oauth/token` (non-JSON:API endpoint using `application/json`)
- **Authorization**: All JSON:API endpoints require Bearer token except user signup
- **User scoping**: Controllers query through the association (`current_user.boards.find_by(id:)`), never `Model.find`
- **Current user access**: `ApplicationController#current_user` resolves `doorkeeper_token.resource_owner_id`
- **Unowned records return 404, not 403**, to avoid ID enumeration

### Key Architectural Patterns

**Attribute Mapping**: Wire attribute names differ from column names and are mapped by hand in
each controller's serializer and writer, e.g. in `BoardsController`:
```ruby
"options" => board.board_options
board.icon = attributes["icon-extended"] || attributes["icon"]
```
`boards` also exposes a computed `icon` that returns the stored icon only when it is one of
`ORIGINAL_ICONS`, alongside the raw `icon-extended`.

**Partial Updates**: Update actions assign an attribute only when its key is present
(`if attributes.key?("name")`), so omitted keys are left untouched.

**User Association**: Records are built through the current user's association
(`current_user.boards.new(...)`), and only an explicit attribute allowlist is read from the
payload — a client-supplied user is simply never consulted.

**Side Effects**: Written inline in the create action — e.g. `BoardsController#create` creates
a default `"All Cards"` column and an empty card after the board saves.

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

The migration off `jsonapi-resources` to hand-written controllers is **complete** — all 21
JSON:API endpoints (Boards 4, Columns 4, Elements 4, Users 4, Cards 5). See
[docs/API_ENDPOINT_MIGRATION_PLAN.md](docs/API_ENDPOINT_MIGRATION_PLAN.md) for the per-endpoint
record and the test-coverage checklist it established, which still applies to new endpoints.

## Technology Stack

- Rails
- Ruby
- PostgreSQL (required)
- Gems:
  - `doorkeeper` - OAuth2 provider
  - `bcrypt` - Password hashing
  - `rack-cors` - CORS handling
  - `httparty` - Webhook HTTP client (`lib/webhook_client.rb`, used by `POST /shares`)
  - `standard` - Ruby linting/formatting
  - `rspec-rails` - Testing framework
  - `factory_bot_rails` - Test data factories
