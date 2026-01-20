# Riverbed Backend API Endpoints

This document lists all backend API endpoints called by the iOS application, including HTTP methods, URL parameters, query parameters, and request bodies. This checklist is intended for migrating backend routes to a new implementation.

## Base URL
- Production: `https://api.riverbed.app/`
- Local Development: `http://localhost:3000/` (commented out in code)

## Authentication
All endpoints (except token creation and user signup) require Bearer token authentication via the `Authorization` header:
```
Authorization: Bearer {access_token}
```

---

## Authentication Endpoints

### 1. Create OAuth Token (Sign In)
- **Endpoint**: `/oauth/token`
- **HTTP Method**: `POST`
- **URL Parameters**: None
- **Query Parameters**: None
- **Authentication**: None (public endpoint)
- **Content-Type**: `application/json`
- **Request Body**:
  ```json
  {
    "grant_type": "password",
    "username": "{email}",
    "password": "{password}"
  }
  ```
- **Response**: JSON object with the following structure:
  ```json
  {
    "access_token": "{string - OAuth access token}",
    "token_type": "{string - typically 'Bearer'}",
    "created_at": {integer - Unix timestamp},
    "user_id": {integer - ID of the authenticated user}
  }
  ```
- **Implementation**: `TokenStore.swift` - `create(email:password:completion:)`

---

## User Endpoints

### 2. Create User (Sign Up)
- **Endpoint**: `/users`
- **HTTP Method**: `POST`
- **URL Parameters**: None
- **Query Parameters**: None
- **Authentication**: The iOS app always sends an `Authorization: Bearer {token}` header. During signup when no user is authenticated, the token will be an empty string (`Bearer `). The backend should treat this endpoint as public and either ignore the Authorization header or handle empty/invalid tokens gracefully during user registration.
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with the following structure:
  ```json
  {
    "data": {
      "type": "users",
      "attributes": {
        "email": "{string - user's email address}",
        "password": "{string - user's password}",
        "allow-emails": {boolean - optional, user's email preference}
      }
    }
  }
  ```
- **Implementation**: `UserStore.swift` - `create(with:completion:)`

### 3. Get User
- **Endpoint**: `/users/{userId}`
- **HTTP Method**: `GET`
- **URL Parameters**: 
  - `userId` - The ID of the user to retrieve
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `UserStore.swift` - `find(_:completion:)`

### 4. Update User
- **Endpoint**: `/users/{userId}`
- **HTTP Method**: `PATCH`
- **URL Parameters**: 
  - `userId` - The ID of the user to update
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with updated user attributes
- **Implementation**: `UserStore.swift` - `update(_:with:completion:)`

### 5. Delete User
- **Endpoint**: `/users/{userId}`
- **HTTP Method**: `DELETE`
- **URL Parameters**: 
  - `userId` - The ID of the user to delete
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `UserStore.swift` - `delete(_:completion:)`

---

## Board Endpoints

### 6. List All Boards
- **Endpoint**: `/boards`
- **HTTP Method**: `GET`
- **URL Parameters**: None
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `BoardStore.swift` - `all(completion:)`

### 7. Create Board
- **Endpoint**: `/boards`
- **HTTP Method**: `POST`
- **URL Parameters**: None
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with board attributes and options
- **Implementation**: `BoardStore.swift` - `create(completion:)`

### 8. Update Board
- **Endpoint**: `/boards/{boardId}`
- **HTTP Method**: `PATCH`
- **URL Parameters**: 
  - `boardId` - The ID of the board to update
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with updated board attributes
- **Implementation**: `BoardStore.swift` - `update(_:with:completion:)`

### 9. Delete Board
- **Endpoint**: `/boards/{boardId}`
- **HTTP Method**: `DELETE`
- **URL Parameters**: 
  - `boardId` - The ID of the board to delete
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `BoardStore.swift` - `delete(_:completion:)`

---

## Column Endpoints

### 10. List Columns for Board
- **Endpoint**: `/boards/{boardId}/columns`
- **HTTP Method**: `GET`
- **URL Parameters**: 
  - `boardId` - The ID of the board whose columns to retrieve
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `ColumnStore.swift` - `all(for:completion:)`

### 11. Create Column
- **Endpoint**: `/columns`
- **HTTP Method**: `POST`
- **URL Parameters**: None
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with column attributes and board relationship
- **Implementation**: `ColumnStore.swift` - `create(on:completion:)`

### 12. Update Column
- **Endpoint**: `/columns/{columnId}`
- **HTTP Method**: `PATCH`
- **URL Parameters**: 
  - `columnId` - The ID of the column to update
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with updated column attributes (including displayOrder)
- **Note**: Multiple PATCH requests are made sequentially when updating display orders of multiple columns
- **Implementation**: `ColumnStore.swift` - `update(_:with:completion:)` and `updateDisplayOrders(of:completion:)`

### 13. Delete Column
- **Endpoint**: `/columns/{columnId}`
- **HTTP Method**: `DELETE`
- **URL Parameters**: 
  - `columnId` - The ID of the column to delete
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `ColumnStore.swift` - `delete(_:completion:)`

---

## Element Endpoints

### 14. List Elements for Board
- **Endpoint**: `/boards/{boardId}/elements`
- **HTTP Method**: `GET`
- **URL Parameters**: 
  - `boardId` - The ID of the board whose elements to retrieve
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `ElementStore.swift` - `all(for:completion:)`

### 15. Create Element
- **Endpoint**: `/elements`
- **HTTP Method**: `POST`
- **URL Parameters**: None
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with element attributes (elementType, dataType) and board relationship
- **Implementation**: `ElementStore.swift` - `create(of:on:completion:)`

### 16. Update Element
- **Endpoint**: `/elements/{elementId}`
- **HTTP Method**: `PATCH`
- **URL Parameters**: 
  - `elementId` - The ID of the element to update
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with updated element attributes (including displayOrder)
- **Note**: Multiple PATCH requests are made sequentially when updating display orders of multiple elements
- **Implementation**: `ElementStore.swift` - `update(_:with:completion:)` and `updateDisplayOrders(of:completion:)`

### 17. Delete Element
- **Endpoint**: `/elements/{elementId}`
- **HTTP Method**: `DELETE`
- **URL Parameters**: 
  - `elementId` - The ID of the element to delete
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `ElementStore.swift` - `delete(_:completion:)`

---

## Card Endpoints

### 18. List Cards for Board
- **Endpoint**: `/boards/{boardId}/cards`
- **HTTP Method**: `GET`
- **URL Parameters**: 
  - `boardId` - The ID of the board whose cards to retrieve
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `CardStore.swift` - `all(for:completion:)`

### 19. Get Card by ID
- **Endpoint**: `/cards/{cardId}`
- **HTTP Method**: `GET`
- **URL Parameters**: 
  - `cardId` - The ID of the card to retrieve
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `CardStore.swift` - `find(_:completion:)`

### 20. Create Card
- **Endpoint**: `/cards`
- **HTTP Method**: `POST`
- **URL Parameters**: None
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with card attributes (fieldValues) and board relationship
- **Implementation**: `CardStore.swift` - `create(on:with:completion:)`

### 21. Update Card
- **Endpoint**: `/cards/{cardId}`
- **HTTP Method**: `PATCH`
- **URL Parameters**: 
  - `cardId` - The ID of the card to update
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/vnd.api+json`
- **Request Body**: JSON:API format with updated card attributes (fieldValues)
- **Implementation**: `CardStore.swift` - `update(_:with:completion:)`

### 22. Delete Card
- **Endpoint**: `/cards/{cardId}`
- **HTTP Method**: `DELETE`
- **URL Parameters**: 
  - `cardId` - The ID of the card to delete
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Implementation**: `CardStore.swift` - `delete(_:completion:)`

---

## Webhook/Share Endpoints

### 23. Post Webhook/Share
- **Endpoint**: `/shares`
- **HTTP Method**: `POST`
- **URL Parameters**: None
- **Query Parameters**: None
- **Authentication**: Required (Bearer token)
- **Content-Type**: `application/json`
- **Request Body**: JSON object with the following fields:
  ```json
  {
    "url": "{string - URL being shared}",
    "title": "{string - optional title/description of the URL}"
  }
  ```
- **Expected Response**: HTTP 204 No Content
- **Note**: Has a 5-second timeout configured
- **Implementation**: `WebhookStore.swift` - `postWebhook(bodyDict:completion:)`

---

## Summary

### Total Endpoints: 23

#### By Resource:
- **Authentication**: 1 endpoint
- **Users**: 4 endpoints (Create, Read, Update, Delete)
- **Boards**: 4 endpoints (List, Create, Update, Delete)
- **Columns**: 4 endpoints (List, Create, Update, Delete)
- **Elements**: 4 endpoints (List, Create, Update, Delete)
- **Cards**: 5 endpoints (List by Board, Get by ID, Create, Update, Delete)
- **Webhooks/Shares**: 1 endpoint (Create)

#### By HTTP Method:
- **GET**: 6 endpoints
- **POST**: 7 endpoints
- **PATCH**: 7 endpoints
- **DELETE**: 5 endpoints

### Notes:
1. All endpoints use JSON:API format (`application/vnd.api+json`) except:
   - Token creation endpoint uses `application/json`
   - Webhook/share endpoint uses `application/json`
2. No query string parameters are currently used by any endpoint
3. All authenticated endpoints require Bearer token in Authorization header
4. Date fields use a custom server date-time format (`DateTimeUtils.serverDateTimeFormatter`)
5. The application supports both production (`https://api.riverbed.app/`) and local development (`http://localhost:3000/`) base URLs
