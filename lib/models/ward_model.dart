class WardModel {
  final String id;
  final String name;
  final String? supervisorId;
  final DateTime createdAt;

  WardModel({
    required this.id,
    required this.name,
    this.supervisorId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get wardId => id;

  Map<String, dynamic> toJson() {
    return {
      'wardId': id,
      'id': id,
      'name': name,
      'supervisorId': supervisorId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WardModel.fromMap(Map<String, dynamic> map, String id) {
    return WardModel(
      id: id,
      name: map['name'] ?? '',
      supervisorId: map['supervisorId'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  WardModel copyWith({
    String? id,
    String? name,
    String? supervisorId,
    DateTime? createdAt,
  }) {
    return WardModel(
      id: id ?? this.id,
      name: name ?? this.name,
      supervisorId: supervisorId ?? this.supervisorId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
