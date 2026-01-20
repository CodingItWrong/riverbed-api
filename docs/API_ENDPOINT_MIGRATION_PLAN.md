# Backend API Migration Plan (JSON:API Endpoints Only)

Use this document to track the migration of JSON:API backend routes to the new implementation. For detailed information about all endpoints (including non-JSON:API endpoints like OAuth and webhooks), see [API_ENDPOINTS.md](./API_ENDPOINTS.md).

**Note**: This plan only includes endpoints that use JSON:API format (`application/vnd.api+json`). Non-JSON:API endpoints (OAuth token creation and webhook/share) are documented in API_ENDPOINTS.md but excluded from this plan.

---

## Test Coverage Requirements

For each endpoint, ensure comprehensive test coverage including:

### 1. Basic CRUD Operations
- [ ] Test successful operations for each HTTP method (GET, POST, PATCH, DELETE)
- [ ] Verify correct HTTP status codes (200, 201, 204, 400, 401, 404)
- [ ] Test both collection and individual resource retrieval where applicable

### 2. Authentication & Authorization
- [ ] Test logged out (401 unauthorized) scenarios for all endpoints
- [ ] Test logged in user can access their own resources
- [ ] Test user cannot access resources belonging to other users (404)
- [ ] Verify empty response body for 401 errors

### 3. JSON:API Format Compliance
- [ ] Assert `Content-Type: application/vnd.api+json` header on all responses
- [ ] Send `Content-Type: application/vnd.api+json` header in request headers
- [ ] Validate response structure has required top-level keys (`data` or `errors`)
- [ ] Validate resource objects have `type`, `id`, and `attributes` keys
- [ ] Validate error objects have `code` and `title` keys
- [ ] Ensure `data` is Array for collections, Hash for single resources
- [ ] Ensure `errors` key is present (not `data`) for error responses

### 4. Complete Attribute Coverage
- [ ] Test reading all resource attributes in GET responses
- [ ] Test creating resources with all writable attributes in POST
- [ ] Test updating all writable attributes in PATCH
- [ ] Verify correct attribute name transformations (snake_case to kebab-case)
- [ ] Test delegated attributes (e.g., `options` delegates to `board_options`)
- [ ] Verify computed/virtual attributes return correctly

### 5. Error Handling & Validation
- [ ] Test invalid JSON syntax returns 400
- [ ] Test missing `data` key returns 400 with JSON:API error structure
- [ ] Test missing `type` in data returns 400 with JSON:API error structure
- [ ] Test wrong `type` in data returns 400 with JSON:API error structure
- [ ] Test ID mismatch (URL vs payload) in PATCH returns 400
- [ ] Verify all validation errors return proper JSON:API error structure
- [ ] Test that operations don't modify data when errors occur

### 6. Side Effects & Business Logic
- [ ] Test any side effects of create operations (e.g., default related records)
- [ ] Test cascading deletes where applicable
- [ ] Test any computed fields or transformations
- [ ] Verify database state changes match expectations

### 7. Security
- [ ] Test that user field cannot be set/modified via attributes to prevent user tampering (for resources that belong to a user)
- [ ] Verify resources are always associated with the authenticated user on create
- [ ] Verify user association cannot be changed on update

---

## Users
- [ ] `POST /users` - Create user (sign up)
- [ ] `GET /users/{userId}` - Get user by ID
- [ ] `PATCH /users/{userId}` - Update user
- [ ] `DELETE /users/{userId}` - Delete user

## Boards
- [x] `GET /boards` - List all boards
- [x] `POST /boards` - Create board
- [x] `PATCH /boards/{boardId}` - Update board
- [x] `DELETE /boards/{boardId}` - Delete board

**Test Coverage**: ✅ Complete

## Columns
- [ ] `GET /boards/{boardId}/columns` - List columns for board
- [ ] `POST /columns` - Create column
- [ ] `PATCH /columns/{columnId}` - Update column (including display order)
- [ ] `DELETE /columns/{columnId}` - Delete column

## Elements
- [ ] `GET /boards/{boardId}/elements` - List elements for board
- [ ] `POST /elements` - Create element
- [ ] `PATCH /elements/{elementId}` - Update element (including display order)
- [ ] `DELETE /elements/{elementId}` - Delete element

## Cards
- [ ] `GET /boards/{boardId}/cards` - List cards for board
- [ ] `GET /cards/{cardId}` - Get card by ID
- [ ] `POST /cards` - Create card
- [ ] `PATCH /cards/{cardId}` - Update card
- [ ] `DELETE /cards/{cardId}` - Delete card

---

## Migration Progress Summary
- Total JSON:API Endpoints: 21
- Completed: 4 (Boards)
- Remaining: 17

## Excluded Non-JSON:API Endpoints
The following endpoints use standard JSON format and are excluded from this plan:
- `POST /oauth/token` - OAuth token creation (uses `application/json`)
- `POST /shares` - Webhook/share posting (uses `application/json`)

## Notes for Migration
1. All endpoints in this plan use JSON:API format (`application/vnd.api+json`)
2. All endpoints (except user signup) require Bearer token authentication
3. User signup sends an empty Bearer token when unauthenticated
4. No query string parameters are currently used
5. Date fields use a custom server date-time format
6. Base URL: `https://api.riverbed.app/` (production) or `http://localhost:3000/` (development)

## Reference Implementation

See `spec/requests/boards_spec.rb` for a complete reference implementation that follows all test coverage requirements above. This spec includes:
- All CRUD operations with success and failure scenarios
- Authentication and authorization checks
- Complete JSON:API format validation
- All board attributes (name, icon, icon-extended, color-theme, favorited-at, options)
- Comprehensive error handling for malformed payloads
- Side effect verification (default column and card creation)
- Security tests preventing user field tampering on create and update
