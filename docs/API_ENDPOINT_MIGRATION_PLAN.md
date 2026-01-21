# Backend API Migration Plan (JSON:API Endpoints Only)

Use this document to track the migration of JSON:API backend routes to the new implementation. For detailed information about all endpoints (including non-JSON:API endpoints like OAuth and webhooks), see [API_ENDPOINTS.md](./API_ENDPOINTS.md).

**Note**: This plan only includes endpoints that use JSON:API format (`application/vnd.api+json`). Non-JSON:API endpoints (OAuth token creation and webhook/share) are documented in API_ENDPOINTS.md but excluded from this plan.

---

## Migration Process

**CRITICAL**: For each endpoint migration, follow this two-phase approach:

### Phase 1: Expand Test Coverage (Tests Must Pass)
1. Review the existing resource and controller implementation
2. Add comprehensive tests following the Test Coverage Requirements below
3. **Verify all tests pass with the current JSONAPI::Resources implementation**
4. This ensures you have complete test coverage before changing the implementation

### Phase 2: Reimplement Without JSONAPI::Resources
1. Update routes from `jsonapi_resources` to standard Rails `resources`
2. Reimplement controller to handle JSON:API format directly (no JSONAPI::ActsAsResourceController)
3. **Run tests to verify all existing tests still pass**
4. If the resource is still needed for nested routes, create a minimal resource with only:
   - Relationship declarations (for nested route support)
   - `records` method (for authorization scoping)

**Why This Order Matters**: Writing comprehensive tests first ensures that when you reimplement the controller, you can verify that all functionality is preserved. If you change the implementation before having good tests, you risk silently breaking features.

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
- [ ] Verify resources are always associated with the authenticated user on create

---

## Users
- [x] `POST /users` - Create user (sign up)
- [x] `GET /users/{userId}` - Get user by ID
- [x] `PATCH /users/{userId}` - Update user
- [x] `DELETE /users/{userId}` - Delete user

**Test Coverage**: ✅ Complete

## Boards
- [x] `GET /boards` - List all boards
- [x] `POST /boards` - Create board
- [x] `PATCH /boards/{boardId}` - Update board
- [x] `DELETE /boards/{boardId}` - Delete board

**Test Coverage**: ✅ Complete

## Columns
- [x] `GET /boards/{boardId}/columns` - List columns for board
- [x] `POST /columns` - Create column
- [x] `PATCH /columns/{columnId}` - Update column (including display order)
- [x] `DELETE /columns/{columnId}` - Delete column

**Test Coverage**: ✅ Complete

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
- Completed: 12 (Boards: 4, Columns: 4, Users: 4)
- Remaining: 9 (Elements: 4, Cards: 5)

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

**Primary Reference: `spec/requests/columns_spec.rb`**

This is the recommended reference for migrating remaining endpoints. It demonstrates:
- All CRUD operations including nested routes (`GET /boards/:id/columns`)
- Complete attribute coverage with delegated attributes (`card-sort-order` → `sort_order`)
- Relationship handling (board association on create, preventing relationship updates)
- Comprehensive JSON:API format validation
- All error scenarios (invalid JSON, missing/wrong type, ID mismatch, unauthorized access)
- User association verification on create

The columns spec is more representative of the remaining endpoints (elements, cards) since they:
- Have relationships to boards (like columns do)
- Use delegated attributes
- Need nested route support

**Alternative Reference: `spec/requests/boards_spec.rb`**

Boards spec includes additional patterns like:
- Side effect verification (creating default related records)
- User field tampering prevention (works in new implementation but not with JSONAPI::Resources during Phase 1)
- Multiple delegated attributes (`icon-extended` → `icon`, `options` → `board_options`)
