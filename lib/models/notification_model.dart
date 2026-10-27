import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String recipientId;
  final String title;
  final String message;
  final String type;
  final String? relatedId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isRead;

  const NotificationModel({
    required this.notificationId,
    required this.recipientId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    required this.createdAt,
    required this.expiresAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'recipientId': recipientId,
        'title': title,
        'message': message,
        'type': type,
        'relatedId': relatedId,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isRead': isRead,
      };

  factory NotificationModel.fromMap(
    Map<String, dynamic> map,
    String notificationId,
  ) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? fallback;
      return fallback;
    }

    final createdAt = parseDate(map['createdAt'], DateTime.now());
    return NotificationModel(
      notificationId: notificationId,
      recipientId: (map['recipientId'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      message: (map['message'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'general',
      relatedId: map['relatedId'] as String?,
      createdAt: createdAt,
      expiresAt: parseDate(
        map['expiresAt'],
        createdAt.add(const Duration(days: 45)),
      ),
      isRead: map['isRead'] == true,
    );
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        notificationId: notificationId,
        recipientId: recipientId,
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        createdAt: createdAt,
        expiresAt: expiresAt,
        isRead: isRead ?? this.isRead,
      );
}
