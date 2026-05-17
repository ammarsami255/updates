# Migration Plan: Old → New Architecture

## Overview
This document outlines the step-by-step migration from the old architecture (static singletons, services folder) to the new Clean Architecture (features, repositories, use cases).

## Old Architecture Issues
1. Static singletons everywhere (AuthService, ChatService, etc.)
2. No dependency injection
3. Firebase code mixed with business logic
4. No use cases - direct service calls
5. No testability
6. Incomplete feature folders

## New Architecture Benefits
1. **Testability** - All dependencies injectable/mockable
2. **Separation of Concerns** - Domain layer has NO Firebase code
3. **Maintainability** - Changes isolated to layers
4. **Scalability** - Easy to add features
5. **CI/CD Ready** - Can test each layer independently

---

## Migration Steps

### Phase 1: Foundation (Week 1)
- [x] Create core layer (failures, etc.)
- [x] Create dependency injection setup
- [ ] Update pubspec.yaml with new dependencies
- [ ] Create base test structure

### Phase 2: Auth Feature (Week 1-2)
- [x] Domain: Entities, Repository interface, Use cases
- [x] Data: Models, Data sources, Repository implementation
- [x] Presentation: BLoC, Screens (stub), Widgets
- [ ] Integrate with main.dart
- [ ] Write unit tests

### Phase 3: Chat Feature (Week 2)
- [x] Domain: Entities, Repository interface, Use cases
- [x] Data: Models, Data sources, Repository implementation
- [x] Presentation: BLoC, Screens (stub), Widgets
- [ ] Write unit tests

### Phase 4: Listings Feature (Week 2-3)
- [x] Domain: Entities, Repository interface, Use cases
- [x] Data: Models, Data sources, Repository implementation
- [ ] Presentation: BLoC, Screens
- [ ] Write unit tests

### Phase 5: User Profile Feature (Week 3)
- [x] Domain: Entities, Repository interface, Use cases
- [x] Data: Models, Data sources, Repository implementation
- [ ] Presentation: BLoC, Screens
- [ ] Write unit tests

### Phase 6: UI Migration (Week 3-4)
- [ ] Update all screens to use BLoC providers
- [ ] Remove all StreamBuilder (use BLoC state)
- [ ] Connect to use cases
- [ ] Test UI interaction

### Phase 7: Cleanup (Week 4)
- [ ] Delete old services folder
- [ ] Delete old models folder
- [ ] Delete old screens folder
- [ ] Update routing
- [ ] Final integration tests

---

## Code Comparison

### OLD: AuthService (static singleton)
```dart
// lib/services/auth_service.dart
class AuthService {
  AuthService._();
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static Future<AuthResult> login(...) async { ... }
  static Future<AuthResult> register(...) async { ... }
  static User? get currentUser => _auth.currentUser;
}
```

### NEW: Auth Feature (Clean Architecture)
```dart
// lib/features/auth/domain/entities/auth_user.dart
class AuthUser extends Equatable { ... }

// lib/features/auth/domain/repositories/auth_repository.dart
abstract class AuthRepository {
  Future<({AuthUser?, Failure?})> getCurrentUser();
  Future<({AuthUser, Failure?})> signInWithEmail(...);
  // ... NO Firebase code here
}

// lib/features/auth/data/repositories/auth_repository_impl.dart
class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource _dataSource;
  // Firebase code HERE only
}

// lib/features/auth/presentation/bloc/auth_bloc.dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  // Uses use cases, not services
}
```

---

## Key Changes

### Before (Old)
```
lib/
 ├── services/          # Static singletons
 │   ├── auth_service.dart
 │   ├── chat_service.dart
 │   └── ...
 ├── models/           # Mixed with data logic
 ├── screens/         # Business logic in UI
 └── main.dart        # Firebase init + app
```

### After (New)
```
lib/
 ├── core/            # Shared errors, utils
 ├── features/       # Each feature isolated
 │   ├── auth/
 │   │   ├── data/        # Firestore code
 │   │   ├── domain/      # Business logic (NO Firebase)
 │   │   └── presentation/ # BLoC, UI
 │   ├── chat/
 │   └── ...
 ├── infrastructure/  # DI, config
 ├── shared/         # Common widgets
 └── main.dart      # DI setup + BLoC providers
```

---

## Testing Strategy

### Unit Tests
- Repository tests (mock data sources)
- Use case tests (mock repositories)
- BLoC tests (mock use cases)

### Widget Tests
- Screen rendering
- User interactions
- State changes

### Integration Tests
- Full flow (auth → chat → listing)
- Navigation
- Error states

---

## Rollback Plan
If migration fails:
1. Keep old code in separate folder
2. Feature flag for new architecture
3. Gradual cutover by feature
4. Full switch after testing

---

## Success Criteria
- [ ] All old static singletons removed
- [ ] 80%+ test coverage
- [ ] No Firebase code in domain layer
- [ ] All features use BLoC pattern
- [ ] CI/CD pipeline passing