class StoredCode {
  final String id;
  String name;
  final String imagePath;
  final DateTime createdAt;

  StoredCode({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StoredCode.fromJson(Map<String, dynamic> json) => StoredCode(
    id: json['id'] as String,
    name: json['name'] as String,
    imagePath: json['imagePath'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
