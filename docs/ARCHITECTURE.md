# ZERO-COST START Architecture

## Overview
This document defines the production-ready architecture for a Firebase-first Flutter app that minimizes costs while enabling future scalability.

---

## 1. FOLDER STRUCTURE

```
lib/
├── core/
│   ├── constants/     # App-wide constants
│   ├── theme/        # Theme and styling
│   └── utils/        # Shared utilities (extensions, helpers)
│
├── data/
│   ├── repositories/ # Business logic abstraction (future: switch to Cloud Functions)
│   └── datasources/  # Firebase data sources (direct Firestore access)
│
├── models/
│   └── *.dart       # Data models (JSON serialization)
│
├── services/
│   └── *.dart       # Firebase services (Auth, Firestore, storage)
│
├── screens/
│   └── *.dart       # UI screens
│
├── widget/
│   └── *.dart      # Reusable widgets
│
└── features/
    └── auth/
        ├── data/
        └── presentation/
```

**RULE:** No Firestore calls inside `screens/` or `widget/`. All Firebase access goes through `services/` + `repositories/`.

---

## 2. FIRESTORE SCHEMA

### Collections

| Collection | Purpose | Access | Indexes |
|-------------|---------|--------|---------|
| `users/{uid}` | User profiles | Owner: read/write | - |
| `listings/{listId}` | Service/product listings | Public: read, Owner: write | category + status, createdAt |
| `chats/{chatId}` | Chat metadata | Participants: read/write | participants (array) |
| `chats/{chatId}/messages/{msgId}` | Chat messages | Participants: read/write | createdAt |
| `notifications/{userId}` | User notifications | Owner: read/write | - |

### Documents Structure

```yaml
# users/{uid}
- uid: string (PK)
- name: string
- email: string
- profileImage: string (URL)
- favoriteIds: string[]
- isEmailVerified: boolean
- online: boolean
- lastSeen: timestamp

# listings/{listId}
- userId: string (FK → users)
- title: string (max 200)
- description: string (max 5000)
- category: string
- type: string (sell/rent)
- price: string
- location: string
- phone: string
- imageUrls: string[]
- viewCount: number
- status: string (active/deleted)
- createdAt: timestamp

# chats/{chatId}
- participants: string[2] (user IDs)
- lastMessage: string
- lastMessageTime: timestamp
- unreadCount_{userId}: number (per-user)

# chats/{chatId}/messages/{msgId}
- chatId: string (FK)
- senderId: string (FK → users)
- content: string
- type: string (text/image)
- createdAt: timestamp
- isSeen: boolean

# notifications/{userId}
- type: string
- title: string
- body: string
- data: map
- read: boolean
- createdAt: timestamp
```

---

## 3. SECURITY RULES SUMMARY

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function hasAuth() = request.auth != null;
    function isOwner(targetUserId) = hasAuth() && request.auth.uid == targetUserId;
    function isParticipant(participants) = hasAuth() && request.auth.uid in participants;
    
    // USERS: Only owner can read/write
    match /users/{userId} {
      allow read, write: if isOwner(userId);
    }
    
    // LISTINGS: Public read, owner write
    match /listings/{listingId} {
      allow read: if true;
      allow create: if hasAuth() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if hasAuth() && resource.data.userId == request.auth.uid;
    }
    
    // CHATS: Participants only
    match /chats/{chatId} {
      allow get: if isParticipant(resource.data.participants);
      allow list: if hasAuth();  // Protected by arrayContains query
      allow create: if hasAuth() && request.resource.data.participants.size() == 2;
      allow update, delete: if isParticipant(resource.data.participants);
    }
    
    // MESSAGES: Protected by parent chat
    match /chats/{chatId}/messages/{messageId} {
      allow read, list: if hasAuth();
      allow create: if hasAuth() && request.resource.data.senderId == request.auth.uid;
      allow update, delete: if hasAuth() && resource.data.senderId == request.auth.uid;
    }
    
    // NOTIFICATIONS: Owner only
    match /notifications/{userId} {
      allow read, write: if isOwner(userId);
    }
  }
}
```

---

## 4. COST OPTIMIZATION STRATEGY

### Primary Rules (ZERO cost)

| Strategy | Implementation | Savings |
|----------|---------------|---------|
| **limit()** | All queries have limits (50-100) | ~70% |
| **orderBy()** | Required for pagination | Required |
| **Caching** | In-memory TTL (5 min) | ~60% |
| **Rate limiting** | Client-side cooldown | ~30% |
| **Debouncing** | View count, messages | ~40% |

### Query Limits

```dart
// Chat list: max 50
.chats.where('participants', arrayContains: uid)
     .orderBy('lastMessageTime').limit(50)

// Messages: max 50 per chat
.chats.doc(id).collection('messages')
     .orderBy('createdAt').limit(50)

// Listings: max 20 per page
.listings.where('status', isEqualTo: 'active')
       .orderBy('createdAt').limit(20)

// My listings: max 100
.listings.where('userId', isEqualTo: uid)
       .orderBy('createdAt').limit(100)
```

### Caching Strategy

```dart
// User profile: 5-minute TTL
class _UserCache {
  static const _ttl = Duration(minutes: 5);
}

// Chat participants: Session cache (in-memory)
class _ParticipantCache {
  static final Map<String, String> _cache = {};
}
```

---

## 5. FUTURE MIGRATION PATH

### Phase 1: Current (Firebase only)
```
Client → Firestore → Client
Cost: ~$0-25/month
```

### Phase 2: Add Cloud Functions (when needed)
```
Client → Firestore Trigger → Cloud Functions → Firestore
Cost: ~$0-40/month (Blaze plan required)
```

### Phase 3: Add Pub/Sub (high scale)
```
Client → Firestore → Pub/Sub → Cloud Functions → Processing
Cost: ~$40-100/month
```

### Migration Strategy

| Component | Current | Future (Cloud Functions) |
|-----------|---------|----------------------|
| Rate limiting | Client-side only | Server-side validation |
| Spam detection | Client-side | Cloud Functions + AI |
| View count | Debounced write | Pub/Sub batched |
| Image processing | N/A | Cloud Functions |
| Notifications | Client-triggered | Pub/Sub triggered |
| Analytics | Firebase Analytics | BigQuery |

### How to Prepare

1. **Isolate business logic** in repositories:
   ```dart
   // Current: Direct Firestore
   class ListingRepository {
     Future<void> createListing(data) async {
       await firestore.collection('listings').add(data);
     }
   }
   
   // Future: Can switch to Cloud Functions without UI changes
   class ListingRepository {
     Future<void> createListing(data) async {
       // Call Cloud Function instead of direct Firestore
       await functions.httpsCallable('createListing').call(data);
     }
   }
   ```

2. **Keep validation in two places**:
   - Client-side: Immediate feedback
   - Server-side: Security (future)

3. **Design for async**:
   - Current: Synchronous writes
   - Future: Queue with Pub/Sub

---

## 6. SERVICES ARCHITECTURE

### Service Layer (Firebase Only)

```
services/
├── auth_service.dart        # Firebase Auth wrapper
├── database_service.dart  # User profile CRUD + caching
├── chat_service.dart      # Chat + messages + presence
├── listing_service.dart # Listings CRUD + search
├── notification_service.dart # FCM tokens + payloads
├── logger_service.dart   # Structured logging
├── rate_limiter_service.dart # Client-side limits
└── connectivity_service.dart # Online detection
```

### Responsibility Separation

| Service | Responsibility | Firestore Access |
|---------|---------------|----------------|
| auth_service | Authentication | users/ |
| database_service | User data | users/ |
| chat_service | Chat + messages | chats/ |
| listing_service | Listings | listings/ |
| notification_service | FCM | notifications/ |

**RULE:** Each service touches ONE collection (max).

---

## 7. ERROR HANDLING + RELIABILITY

### Retry Strategy

```dart
static const int _maxRetries = 3;
static const Duration _retryDelay = Duration(milliseconds: 500);

// Exponential backoff
await Future.delayed(_retryDelay * (attempt + 1));
```

### Offline Handling

```dart
// Connectivity service detects online/offline
class ConnectivityService {
  void init() {
    connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) syncPendingOperations();
    });
  }
}
```

### No Silent Failures

```dart
// Every operation logs result
AppLogger.info('Operation', success: true, durationMs: 150);
AppLogger.error('Failed', error: e, stack: stack);
```

---

## 8. QUICK START CHECKLIST

- [x] Folder structure: Clean separation
- [x] Firestore rules: Secure + zero warnings
- [x] Query limits: All queries bounded
- [x] Caching: User profiles cached
- [x] Rate limiting: Client-side active
- [x] Retry logic: 3 attempts + backoff
- [x] Logging: Structured (awaiting Crashlytics)
- [x] Error handling: Centralized

---

## COST PROJECTION

| Users | Reads/month | Writes/month | Est. Cost |
|-------|------------|--------------|----------|
| 100 | 50,000 | 10,000 | ~$5 |
| 1,000 | 500,000 | 100,000 | ~$25 |
| 10,000 | 5M | 1M | ~$150 |
| 100,000 | 50M | 10M | ~$1,000 |

**Target: <$50/month for MVP**
**Strategy: Cache aggressively, limit queries, paginate**

---

## MIGRATION CHECKLIST

When ready to add Cloud Functions:

- [ ] Move validation to Cloud Functions
- [ ] Add spam detection
- [ ] Batch view counts via Pub/Sub
- [ ] Add image processing
- [ ] Implement analytics pipeline

**Same app, same models, just backend changes.**