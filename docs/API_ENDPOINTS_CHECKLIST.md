# Backend API Migration Checklist (JSON:API Endpoints Only)

Use this checklist to track the migration of JSON:API backend routes to the new implementation. For detailed information about all endpoints (including non-JSON:API endpoints like OAuth and webhooks), see [API_ENDPOINTS.md](./API_ENDPOINTS.md).

**Note**: This checklist only includes endpoints that use JSON:API format (`application/vnd.api+json`). Non-JSON:API endpoints (OAuth token creation and webhook/share) are documented in API_ENDPOINTS.md but excluded from this checklist.

---

## Users
- [ ] `POST /users` - Create user (sign up)
- [ ] `GET /users/{userId}` - Get user by ID
- [ ] `PATCH /users/{userId}` - Update user
- [ ] `DELETE /users/{userId}` - Delete user

## Boards
- [ ] `GET /boards` - List all boards
- [ ] `POST /boards` - Create board
- [ ] `PATCH /boards/{boardId}` - Update board
- [ ] `DELETE /boards/{boardId}` - Delete board

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
- Completed: 0
- Remaining: 21

## Excluded Non-JSON:API Endpoints
The following endpoints use standard JSON format and are excluded from this checklist:
- `POST /oauth/token` - OAuth token creation (uses `application/json`)
- `POST /shares` - Webhook/share posting (uses `application/json`)

## Notes for Migration
1. All endpoints in this checklist use JSON:API format (`application/vnd.api+json`)
2. All endpoints (except user signup) require Bearer token authentication
3. User signup sends an empty Bearer token when unauthenticated
4. No query string parameters are currently used
5. Date fields use a custom server date-time format
6. Base URL: `https://api.riverbed.app/` (production) or `http://localhost:3000/` (development)
