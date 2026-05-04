class Room {
  final String id;
  final String name;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: (json['name'] ?? 'Unnamed Room') as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
