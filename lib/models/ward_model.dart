import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

String formatWardDisplayName(String input) {
  var clean = input.trim();
  if (clean.isEmpty) return 'General';

  // Strip leading 'ward_' or 'ward-' or 'ward ' prefix
  final lower = clean.toLowerCase();
  if (lower.startsWith('ward_') || lower.startsWith('ward-') || lower.startsWith('ward ')) {
    clean = clean.substring(5).trim();
  }

  // Replace underscores and hyphens with single spaces
  clean = clean.replaceAll('_', ' ').replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  // Strip all occurrences of word 'ward' (case-insensitive) to prevent 'icu 1 ward ward' or 'Ward'
  final wordsWithoutWard = clean.split(' ').where((w) => w.trim().toLowerCase() != 'ward').toList();
  clean = wordsWithoutWard.join(' ').trim();

  // Format words dynamically: short acronyms/numbers stay uppercase, words are title-cased
  final formattedWords = clean.split(' ').map((word) {
    if (word.isEmpty) return '';
    // If word is all digits or already all uppercase acronym (e.g. "CCU", "ICU", "OT", "ER", "3")
    if (!word.contains(RegExp(r'[a-z]'))) {
      return word.toUpperCase();
    }
    // If short word (<= 4 chars) without multiple consecutive vowels (e.g. "ccu", "icu", "ot")
    if (word.length <= 4 && !RegExp(r'[aeiou]{2,}', caseSensitive: false).hasMatch(word)) {
      return word.toUpperCase();
    }
    // Standard word title-case (e.g. "minor" -> "Minor", "pediatrics" -> "Pediatrics")
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).where((w) => w.isNotEmpty).join(' ');

  if (formattedWords.isEmpty) return 'General';
  return formattedWords;
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
    final map = <String, dynamic>{
      'id': wardId,
      'wardId': wardId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
    if (supervisorRef != null) {
      map['supervisorRef'] = supervisorRef;
    }
    if (supervisorId != null && supervisorId!.isNotEmpty) {
      map['supervisorId'] = supervisorId;
    }
    return map;
  }

  factory WardModel.fromMap(Map<String, dynamic> map, String id) {
    final rawName = (map['name'] as String?)?.trim() ??
        (map['wardName'] as String?)?.trim() ??
        '';
    final effectiveId = (map['wardId'] as String?) ??
        (map['id'] as String?) ??
        id;
    final formattedName = rawName.isNotEmpty ? formatWardDisplayName(rawName) : formatWardDisplayName(effectiveId);
    return WardModel(
      wardId: effectiveId.isNotEmpty ? effectiveId : id,
      name: formattedName,
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
