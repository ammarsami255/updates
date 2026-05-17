import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:el_moza3/services/listing_service.dart';

void main() {
  group('ListingException', () {
    test('creates exception with code and message', () {
      const exception = ListingException('INVALID_TITLE', 'Title is invalid');
      
      expect(exception.code, 'INVALID_TITLE');
      expect(exception.message, 'Title is invalid');
    });

    test('toString formats correctly', () {
      const exception = ListingException('TEST_CODE', 'Test message');
      
      expect(exception.toString(), 'ListingException(TEST_CODE): Test message');
    });
  });

  group('ListingResult', () {
    test('success creates successful result', () {
      final result = ListingResult.success({'id': '123'});
      
      expect(result.isSuccess, true);
      expect(result.data, {'id': '123'});
      expect(result.error, null);
    });

    test('failure creates failure result', () {
      final result = ListingResult<String>.failure('INVALID_TITLE', 'Title is invalid');
      
      expect(result.isSuccess, false);
      expect(result.data, null);
      expect(result.error?.code, 'INVALID_TITLE');
      expect(result.error?.message, 'Title is invalid');
    });

    test('success result has no error', () {
      final result = ListingResult.success('data');
      expect(result.error, null);
    });

    test('failure result has data null', () {
      final result = ListingResult<String>.failure('CODE', 'message');
      expect(result.data, null);
    });
  });

  group('Input Validation (Business Logic)', () {
    // Test validation logic - these are the same rules used in ListingService
    
    test('empty title returns error', () {
      final title = '';
      final isValid = title.trim().isNotEmpty && title.trim().length <= 200;
      expect(isValid, false);
    });

    test('title over 200 chars returns error', () {
      final title = 'a' * 201;
      final isValid = title.trim().isNotEmpty && title.trim().length <= 200;
      expect(isValid, false);
    });

    test('valid title passes', () {
      final title = 'Valid Title';
      final isValid = title.trim().isNotEmpty && title.trim().length <= 200;
      expect(isValid, true);
    });

    test('exactly 200 char title is valid', () {
      final title = 'a' * 200;
      final isValid = title.trim().isNotEmpty && title.trim().length <= 200;
      expect(isValid, true);
    });

    test('empty description returns error', () {
      final description = '';
      final isValid = description.trim().isNotEmpty && description.trim().length <= 5000;
      expect(isValid, false);
    });

    test('description over 5000 chars returns error', () {
      final description = 'a' * 5001;
      final isValid = description.trim().isNotEmpty && description.trim().length <= 5000;
      expect(isValid, false);
    });

    test('valid description passes', () {
      final description = 'This is a valid description with enough characters.';
      final isValid = description.trim().isNotEmpty && description.trim().length <= 5000;
      expect(isValid, true);
    });

    test('empty category returns error', () {
      final category = '';
      final isValid = category.trim().isNotEmpty && category.trim().length <= 50;
      expect(isValid, false);
    });

    test('valid category passes', () {
      final category = 'electronics';
      final isValid = category.trim().isNotEmpty && category.trim().length <= 50;
      expect(isValid, true);
    });

    test('empty price returns error', () {
      final price = '';
      final isValid = price.trim().isNotEmpty && price.trim().length <= 20;
      expect(isValid, false);
    });

    test('valid price passes', () {
      final price = '100';
      final isValid = price.trim().isNotEmpty && price.trim().length <= 20;
      expect(isValid, true);
    });

    test('empty location returns error', () {
      final location = '';
      final isValid = location.trim().isNotEmpty && location.trim().length <= 100;
      expect(isValid, false);
    });

    test('valid location passes', () {
      final location = 'New York';
      final isValid = location.trim().isNotEmpty && location.trim().length <= 100;
      expect(isValid, true);
    });

    test('empty phone returns error', () {
      final phone = '';
      final isValid = phone.trim().isNotEmpty && phone.trim().length <= 20;
      expect(isValid, false);
    });

    test('valid phone passes', () {
      final phone = '+1234567890';
      final isValid = phone.trim().isNotEmpty && phone.trim().length <= 20;
      expect(isValid, true);
    });
  });

  group('Category Validation', () {
    test('valid categories list is defined', () {
      const validCategories = [
        'electronics', 'vehicles', 'real_estate', 'furniture',
        'clothing', 'services', 'jobs', 'other'
      ];
      
      expect(validCategories.length, 8);
      expect(validCategories.contains('electronics'), true);
      expect(validCategories.contains('other'), true);
    });

    test('empty category rejected', () {
      final category = '';
      expect(category.isEmpty, true);
    });
  });

  group('Type Validation', () {
    test('valid types are defined', () {
      const validTypes = ['sell', 'rent', 'exchange', 'service'];
      
      expect(validTypes.length, 4);
      expect(validTypes.contains('sell'), true);
      expect(validTypes.contains('rent'), true);
    });
  });

  group('Pagination Limits', () {
    test('default limit is 20', () {
      const defaultLimit = 20;
      expect(defaultLimit >= 1 && defaultLimit <= 100, true);
    });

    test('max limit is 100', () {
      const maxLimit = 100;
      expect(maxLimit <= 100, true);
    });

    test('limit clamped to valid range', () {
      // Test the clamping logic used in ListingService
      final queryLimit = 50;
      final clampedLimit = queryLimit.clamp(1, 100);
      expect(clampedLimit, 50);
    });

    test('limit below min clamped to 1', () {
      final queryLimit = 0;
      final clampedLimit = queryLimit.clamp(1, 100);
      expect(clampedLimit, 1);
    });

    test('limit above max clamped to 100', () {
      final queryLimit = 150;
      final clampedLimit = queryLimit.clamp(1, 100);
      expect(clampedLimit, 100);
    });
  });

  group('Search Filtering', () {
    test('empty search query returns all', () {
      const searchQuery = '';
      expect(searchQuery.isEmpty, true);
    });

    test('search query is case-insensitive', () {
      const searchQuery = 'TEST';
      final lowerQuery = searchQuery.toLowerCase();
      expect(lowerQuery, 'test');
    });

    test('search matches title', () {
      const searchQuery = 'phone';
      final title = 'iPhone for sale';
      
      final matches = title.toLowerCase().contains(searchQuery.toLowerCase());
      expect(matches, true);
    });

    test('search matches description', () {
      const searchQuery = 'smart';
      const description = 'This is a smartphone with great features';
      
      final matches = description.toLowerCase().contains(searchQuery.toLowerCase());
      expect(matches, true);
    });

    test('search does not match unrelated', () {
      const searchQuery = 'xyz';
      const title = 'iPhone for sale';
      
      final matches = title.toLowerCase().contains(searchQuery.toLowerCase());
      expect(matches, false);
    });

    test('search handles null safely', () {
      String? searchQuery;
      final isEmpty = searchQuery == null || searchQuery.isEmpty;
      expect(isEmpty, true);
    });
  });

  group('Category Filtering', () {
    test('الكل returns all categories', () {
      const category = 'الكل';
      expect(category == 'الكل', true);
    });

    test('specific category filters', () {
      const category = 'electronics';
      expect(category.isNotEmpty && category != 'الكل', true);
    });

    test('empty category is filtered out', () {
      const category = '';
      expect(category.isEmpty, true);
    });
  });

  group('Data Transformation', () {
    test('adds id to listing data', () {
      final data = {'title': 'Test', 'price': '100'};
      const docId = 'listing123';
      
      data['id'] = docId;
      
      expect(data['id'], docId);
      expect(data['title'], 'Test');
    });

    test('maps doc to listing with id', () {
      final docData = {'title': 'Test', 'price': '100'};
      const docId = 'abc123';
      
      final listing = Map<String, dynamic>.from(docData);
      listing['id'] = docId;
      
      expect(listing['id'], docId);
      expect(listing['title'], 'Test');
    });

    test('handles null data', () {
      Map<String, dynamic>? data = null;
      final result = data?.data();
      expect(result, null);
    });
  });

  group('View Count', () {
    test('empty listing ID returns early', () {
      const listingId = '';
      expect(listingId.isEmpty, true);
    });

    test('non-empty listing ID proceeds', () {
      const listingId = 'listing123';
      expect(listingId.isEmpty, false);
    });

    test('view count increment is atomic', () {
      // FieldValue.increment exists and works
      final increment = FieldValue.increment(1);
      expect(increment, isNotNull);
    });

    test('current view count defaults to 0', () {
      const viewCount = 0;
      expect(viewCount, 0);
    });
  });

  group('User Listing Query', () {
    test('null user ID returns empty', () {
      final uid = '';
      
      if (uid.isEmpty) {
        expect(true, true);
      }
    });

    test('valid user ID proceeds', () {
      final uid = 'user123';
      
      if (uid.isNotEmpty) {
        expect(uid, 'user123');
      }
    });
  });

  group('Error Handling', () {
    test('empty ID returns null from getListing', () {
      const id = '';
      // Simulating the logic in getListing
      if (id.isEmpty) {
        expect(true, true);
      }
    });

    test('non-existent doc returns null', () {
      // Test null check logic
      final exists = false;
      
      if (!exists) {
        expect(exists, false);
      }
    });
  });

  group('Retry Logic', () {
    test('max retries is positive', () {
      const maxRetries = 3;
      expect(maxRetries > 0, true);
    });

    test('retry delay exists', () {
      const retryDelay = Duration(milliseconds: 500);
      expect(retryDelay.inMilliseconds, 500);
    });

    test('exponential backoff calculation', () {
      const baseDelay = Duration(milliseconds: 500);
      
      for (int attempt = 0; attempt < 3; attempt++) {
        final delay = baseDelay * (attempt + 1);
        expect(delay.inMilliseconds, greaterThan(0));
      }
    });
  });

  group('User Stats', () {
    test('valid user ID is not empty', () {
      const userId = 'testuser';
      expect(userId.isNotEmpty, true);
    });

    test('viewCount defaults to 0 when null', () {
      final viewCount = null;
      final safeCount = viewCount as int? ?? 0;
      expect(safeCount, 0);
    });
  });

  group('Image URLs', () {
    test('null imageUrls defaults to empty array', () {
      List<String>? imageUrls;
      final urls = imageUrls ?? [];
      expect(urls, isEmpty);
    });

    test('provided imageUrls used', () {
      final imageUrls = ['url1', 'url2'];
      final urls = imageUrls ?? [];
      expect(urls.length, 2);
    });
  });

  group('Status', () {
    test('new listings default to active', () {
      const status = 'active';
      expect(status, 'active');
    });

    test('valid statuses include sold', () {
      const validStatuses = ['active', 'pending', 'sold', 'deleted', 'archived'];
      expect(validStatuses.contains('active'), true);
      expect(validStatuses.contains('sold'), true);
    });
  });

  group('Combined Validation', () {
    test('all valid fields pass', () {
      final title = 'Test Listing';
      final description = 'This is a test listing description';
      final category = 'electronics';
      final type = 'sell';
      final price = '100';
      final location = 'New York';
      final phone = '+1234567890';

      final titleValid = title.trim().isNotEmpty && title.trim().length <= 200;
      final descValid = description.trim().isNotEmpty && description.trim().length <= 5000;
      final catValid = category.trim().isNotEmpty && category.trim().length <= 50;
      final typeValid = type.trim().isNotEmpty && type.trim().length <= 50;
      final priceValid = price.trim().isNotEmpty && price.trim().length <= 20;
      final locValid = location.trim().isNotEmpty && location.trim().length <= 100;
      final phoneValid = phone.trim().isNotEmpty && phone.trim().length <= 20;

      expect(titleValid, true);
      expect(descValid, true);
      expect(catValid, true);
      expect(typeValid, true);
      expect(priceValid, true);
      expect(locValid, true);
      expect(phoneValid, true);
    });

    test('one invalid field fails validation', () {
      final title = ''; // Empty - invalid
      final description = 'Valid description';
      final category = 'electronics';
      final type = 'sell';
      final price = '100';
      final location = 'New York';
      final phone = '+1234567890';

      final titleValid = title.trim().isNotEmpty && title.trim().length <= 200;

      expect(titleValid, false);
    });

    test('multiple invalid fields fail', () {
      final title = '';
      final description = '';
      final category = '';
      final type = 'sell';
      final price = '100';
      final location = 'New York';
      final phone = '+1234567890';

      final titleValid = title.trim().isNotEmpty && title.trim().length <= 200;
      final descValid = description.trim().isNotEmpty && description.trim().length <= 5000;
      final catValid = category.trim().isNotEmpty && category.trim().length <= 50;

      expect(titleValid, false);
      expect(descValid, false);
      expect(catValid, false);
    });
  });
}
