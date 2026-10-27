import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';

class NotificationBell extends StatelessWidget {
  final String? userId;
  final FirestoreService service;

  const NotificationBell({
    super.key,
    required this.userId,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    if (userId == null || userId!.isEmpty) {
      return const IconButton(
        onPressed: null,
        icon: Icon(Icons.notifications_none_rounded),
      );
    }

    return StreamBuilder<List<NotificationModel>>(
      stream: service.streamNotifications(userId!),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <NotificationModel>[];
        final unreadCount =
            notifications.where((notification) => !notification.isRead).length;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF0F172A),
                size: 24,
              ),
              tooltip: 'Notifications',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => NotificationListSheet(
                  userId: userId!,
                  service: service,
                  notifications: notifications,
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 7,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class NotificationListSheet extends StatelessWidget {
  final String userId;
  final FirestoreService service;
  final List<NotificationModel> notifications;

  const NotificationListSheet({
    super.key,
    required this.userId,
    required this.service,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: notifications.any((item) => !item.isRead)
                        ? () => service.markAllNotificationsRead(userId)
                        : null,
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'No notifications',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 4),
                            leading: Icon(
                              notification.isRead
                                  ? Icons.notifications_none_rounded
                                  : Icons.notifications_active_rounded,
                              color: notification.isRead
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF1D4ED8),
                            ),
                            title: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(notification.message),
                            onTap: notification.isRead
                                ? null
                                : () => service.markNotificationRead(
                                      notification.notificationId,
                                    ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
