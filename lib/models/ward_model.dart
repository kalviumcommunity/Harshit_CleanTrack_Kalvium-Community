import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

class WardModel {
  final String wardId;
  final String name;
  final DocumentReference? supervisorRef;
  final String? supervisorId;
  final DateTime createdAt;

  WardModel({
    required this.wardId,
    required this.name,
    this.supervisorRef,
    this.supervisorId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'wardId': wardId,
      'name': name,
      'supervisorRef': supervisorRef,
      'supervisorId': supervisorId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WardModel.fromMap(Map<String, dynamic> map, String id) {
    return WardModel(
      wardId: id,
      name: map['name'] ?? '',
      supervisorRef: map['supervisorRef'] is DocumentReference ? map['supervisorRef'] as DocumentReference : null,
      supervisorId: map['supervisorId'],
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  WardModel copyWith({
    String? wardId,
    String? name,
    DocumentReference? supervisorRef,
    String? supervisorId,
    DateTime? createdAt,
  }) {
    return WardModel(
      wardId: wardId ?? this.wardId,
      name: name ?? this.name,
      supervisorRef: supervisorRef ?? this.supervisorRef,
      supervisorId: supervisorId ?? this.supervisorId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
