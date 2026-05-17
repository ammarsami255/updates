import 'package:equatable/equatable.dart';

/// Listing entity - represents a marketplace listing
class Listing extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String phone;
  final String title;
  final String description;
  final double price;
  final String? imageUrl;
  final String? category;
  final String? location;
  final ListingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int viewCount;

  const Listing({
    required this.id,
    required this.userId,
    required this.userName,
    required this.phone,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrl,
    this.category,
    this.location,
    this.status = ListingStatus.active,
    required this.createdAt,
    this.updatedAt,
    this.viewCount = 0,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        phone,
        title,
        description,
        price,
        imageUrl,
        category,
        location,
        status,
        createdAt,
        updatedAt,
        viewCount,
      ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'phone': phone,
        'title': title,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'category': category,
        'location': location,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'viewCount': viewCount,
      };
}

enum ListingStatus { active, inactive, sold }

extension ListingStatusExtension on ListingStatus {
  String get name {
    switch (this) {
      case ListingStatus.active:
        return 'active';
      case ListingStatus.inactive:
        return 'inactive';
      case ListingStatus.sold:
        return 'sold';
    }
  }

  static ListingStatus fromString(String value) {
    switch (value) {
      case 'active':
        return ListingStatus.active;
      case 'inactive':
        return ListingStatus.inactive;
      case 'sold':
        return ListingStatus.sold;
      default:
        return ListingStatus.active;
    }
  }
}