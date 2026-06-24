import 'pose_model.dart';

// lib/models/local_pose.dart
class LocalPose {
  final int id;
  final String image;
  final String category;
  final List<String> tags;
  final String difficulty;
  final String name;

  const LocalPose({
    required this.id,
    required this.image,
    required this.category,
    required this.tags,
    required this.difficulty,
    required this.name,
  });

  factory LocalPose.fromJson(Map<String, dynamic> j) => LocalPose(
    id: j['id'],
    image: j['image'],
    category: j['category'],
    tags: List<String>.from(j['tags']),
    difficulty: j['difficulty'],
    name: j['name'],
  );
  PoseModel toModel() => PoseModel(
    name: name,
    description: '',
    difficulty: difficulty,
    cameraAngle: '',
    emoji: '',
    imagePath: image,
  );
}
