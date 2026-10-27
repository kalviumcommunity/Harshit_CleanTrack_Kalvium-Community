# cleantrack

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Notifications

Notifications are stored as individual documents in the Firestore
`notifications` collection. Each document belongs to one recipient and
contains an `isRead` field. The dashboards show the notification bell for the
current user, and opening an item marks it as read.

Every notification also contains an `expiresAt` timestamp set to 45 days after
creation. The app removes expired notification documents when it reads a
recipient's notifications. To guarantee deletion even when no user opens the
app, enable a Firestore TTL policy for the `notifications` collection group
using the `expiresAt` field in the Firebase console or Google Cloud console.
With the Google Cloud CLI, the policy can be enabled with:

```bash
gcloud firestore fields ttls update expiresAt \
  --collection-group=notifications \
  --enable-ttl
```
