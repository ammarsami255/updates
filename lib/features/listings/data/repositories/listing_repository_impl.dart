import '../../domain/entities/listing_entity.dart';
import '../../domain/repositories/listing_repository.dart';
import '../../../../core/errors/failures.dart';
import '../datasources/listing_firestore_datasource.dart';

/// Listing repository implementation
class ListingRepositoryImpl implements ListingRepository {
  final ListingFirestoreDataSource _dataSource;

  ListingRepositoryImpl(this._dataSource);

  @override
  Future<({Listing? listing, Failure? failure})> getListing(String id) {
    return _dataSource.getListing(id);
  }

  @override
  Stream<List<Listing>> getListings({
    String? userId,
    String? category,
    int limit = 20,
  }) {
    return _dataSource.getListings(userId: userId, category: category, limit: limit);
  }

  @override
  Stream<List<Listing>> getMyListings(String userId) => getListings(userId: userId);

  @override
  Future<({String? id, Failure? failure})> createListing({
    required String userName,
    required String phone,
    required String title,
    required String description,
    required double price,
    String? imageUrl,
    String? category,
    String? location,
  }) {
    return _dataSource.createListing(
      userName: userName,
      phone: phone,
      title: title,
      description: description,
      price: price,
      imageUrl: imageUrl,
      category: category,
      location: location,
    );
  }

  @override
  Future<Failure?> updateListing({
    required String id,
    String? title,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    String? location,
    ListingStatus? status,
  }) {
    return _dataSource.updateListing(
      id: id,
      title: title,
      description: description,
      price: price,
      imageUrl: imageUrl,
      category: category,
      location: location,
      status: status,
    );
  }

  @override
  Future<Failure?> deleteListing(String id) {
    return _dataSource.deleteListing(id);
  }

  @override
  Stream<List<Listing>> searchListings(String query, {int limit = 20}) {
    return _dataSource.searchListings(query, limit: limit);
  }
}