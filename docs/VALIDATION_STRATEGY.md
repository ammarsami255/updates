# Server-Side Validation Strategy

## Overview

This document describes the multi-layer validation architecture for the el_moza3 application. The strategy ensures data integrity and security through defense in depth.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLIENT-SIDE (Flutter)                          │
│  - User feedback (immediate validation)                        │
│  - Form field validation                                      │
│  - Type checks                                              │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              FIRESTORE SECURITY RULES                         │
│  - Field existence checks                                   │
│  - Field length limits                                    │
│  - Ownership verification                                │
│  - Role-based access control                             │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              CLOUD FUNCTIONS (Server-Side)                   │
│  - Callable validation (pre-check API)                     │
│  - Firestore triggers (post-write validation)               │
│  - Business logic validation                              │
│  - Rate limiting                                         │
└───────────────────────────────────────────────────────────┘
```

## Validation Constants

### Listing Validation

| Field | Min | Max | Type | Notes |
|-------|-----|-----|------|-------|
| title | 3 | 200 | string | Required |
| description | 10 | 5000 | string | Required |
| category | 1 | 50 | enum | electronics, vehicles, real_estate, furniture, clothing, services, jobs, other |
| type | 1 | 20 | enum | sell, rent, exchange, service |
| price | 1 | 20 | string | Required |
| location | 1 | 100 | string | Required |
| phone | 10 | 20 | string | Required |
| imageUrls | 0 | 10 | array | HTTPS URLs only |
| viewCount | 0 | ∞ | number | Starts at 0, can only increment |
| status | - | - | enum | active, pending, sold, deleted, archived |

### User Profile Validation

| Field | Min | Max | Type | Notes |
|-------|-----|-----|------|-------|
| name | 2 | 100 | string | Required |
| email | - | 254 | string | Valid email format |
| role | - | - | enum | user, admin |
| phone | 0 | 20 | string | Optional |

### Message Validation

| Field | Min | Max | Type | Notes |
|-------|-----|-----|------|-------|
| content | 1 | 2000 | string | Required |
| type | - | - | enum | text, image, system |
| senderId | - | - | string | Must match auth.uid |
| isSeen | - | - | boolean | Read receipt |
| seenAt | - | - | timestamp | When read |

## Firestore Rules (Layer 1)

The first layer of defense. These rules cannot be bypassed by clients.

### Key Rules

```javascript
// Listing CREATE - requires all fields
allow create: if hasVerifiedIdentity()
  && validateRequiredString('title', 3, 200)
  && validateRequiredString('description', 10, 5000)
  && getValue('category') in ['electronics', ...]
  && getValue('type') in ['sell', 'rent', ...]
  && getValue('userId') == request.auth.uid;

// User profile - only owner can create
allow create: if hasVerifiedIdentity()
  && request.auth.uid == userId
  && getValue('role') == 'user';
```

## Cloud Functions (Layer 2)

### Callable Functions (Pre-Check)

These functions allow clients to validate data BEFORE sending:

```dart
// Flutter client usage
final result = await FirebaseFunctions.instance
  .httpsCallable('validateListing')
  .call({
    'title': title,
    'description': description,
    // ... other fields
  });

if (result.data['valid']) {
  // Proceed to create listing
} else {
  // Show errors
  print(result.data['errors']);
}
```

### Firestore Triggers (Post-Write Validation)

These triggers validate data AFTER it's written to Firestore:

```javascript
// Trigger: runs when listing is created
exports.onListingCreated = onDocumentCreated(
  "listings/{listingId}",
  async (event) => {
    const data = event.data.data();
    const errors = validateListingData(data);
    
    if (errors.length > 0) {
      // DELETE invalid data
      await event.data.ref.delete();
      console.log('Invalid listing removed');
    }
  }
);
```

## Validation Flow

### Listing Creation

```
1. Client: User enters listing data
   ↓
2. Client: Call validateListing() Cloud Function
   ↓
3. Server: Validate fields, return errors
   ↓
4. Client: Show errors if any, proceed if valid
   ↓
5. Client: Create listing in Firestore
   ↓
6. Firestore Rules: Verify auth, ownership, required fields
   ↓
7. Cloud Function: onListingCreated trigger fires
   ↓
8. Server: Final validation, delete if invalid
   ↓
9. Complete: Listing is now validated
```

### Client Implementation Guide

```dart
// services/listing_service.dart

class ListingService {
  /// Validate listing before creation
  static Future<List<String>? validateListing(Map<String, dynamic> data) async {
    try {
      final result = await FirebaseFunctions.instance
        .httpsCallable('validateListing')
        .call(data);
      
      if (result.data['valid'] == true) {
        return null; // No errors
      }
      return List<String>.from(result.data['errors']);
    } catch (e) {
      // Network error - use local validation
      return _validateLocally(data);
    }
  }
  
  /// Create listing with validation
  static Future<String?> createListing(Map<String, dynamic> data) async {
    // First validate
    final errors = await validateListing(data);
    if (errors != null && errors.isNotEmpty) {
      return errors.first;
    }
    
    // Proceed to create
    try {
      await FirebaseFirestore.instance
        .collection('listings')
        .add(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
```

## Security Considerations

1. **Defense in Depth**: Multiple layers ensure security even if one is bypassed
2. **Fail-Safe**: Invalid data is deleted, not allowed
3. **Logging**: All validation failures are logged for audit
4. **Rate Limiting**: Prevents abuse of validation endpoints
5. **Email Verification**: Required for all sensitive operations

## Deployment

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Cloud Functions
firebase deploy --only functions

# Deploy both
firebase deploy
```

## Monitoring

Check Cloud Functions logs for validation failures:

```bash
firebase functions:log --filter "validation"
```
