class PoseModel {
  final String name;
  final String description;
  final String difficulty;
  final String cameraAngle;
  final String emoji;
  final String? imagePath;
  bool isFavourite;

  PoseModel({
    required this.name,
    required this.description,
    required this.difficulty,
    required this.cameraAngle,
    required this.emoji,
    this.imagePath,
    this.isFavourite = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'difficulty': difficulty,
    'cameraAngle': cameraAngle,
    'emoji': emoji,
    'imagePath': imagePath,
  };

  factory PoseModel.fromJson(Map<String, dynamic> json) => PoseModel(
    name: json['name'],
    description: json['description'],
    difficulty: json['difficulty'],
    cameraAngle: json['cameraAngle'],
    emoji: json['emoji'],
    imagePath: json['imagePath'],
  );
}
