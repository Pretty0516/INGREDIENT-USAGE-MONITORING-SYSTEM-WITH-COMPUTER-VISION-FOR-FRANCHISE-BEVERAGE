import 'package:cloud_firestore/cloud_firestore.dart';

class FranchiseModel {
  final String id;
  final String name;
  final String address;
  final String contactEmail;
  final String contactPhone;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final Map<String, dynamic>? settings;
  final List<String> staffIds;

  FranchiseModel({
    required this.id,
    required this.name,
    required this.address,
    required this.contactEmail,
    required this.contactPhone,
    required this.ownerId,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.settings,
    this.staffIds = const [],
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'settings': settings,
      'staffIds': staffIds,
    };
  }

  // Create from Firestore document
  factory FranchiseModel.fromMap(Map<String, dynamic> map) {
    return FranchiseModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      ownerId: map['ownerId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: map['isActive'] ?? true,
      settings: map['settings'],
      staffIds: List<String>.from(map['staffIds'] ?? []),
    );
  }

  // Create a copy with updated fields
  FranchiseModel copyWith({
    String? id,
    String? name,
    String? address,
    String? contactEmail,
    String? contactPhone,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Map<String, dynamic>? settings,
    List<String>? staffIds,
  }) {
    return FranchiseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      settings: settings ?? this.settings,
      staffIds: staffIds ?? this.staffIds,
    );
  }

  @override
  String toString() {
    return 'FranchiseModel(id: $id, name: $name, ownerId: $ownerId, staffCount: ${staffIds.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FranchiseModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}