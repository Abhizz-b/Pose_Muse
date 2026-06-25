import 'package:hive/hive.dart';

part 'album_model.g.dart';

@HiveType(typeId: 10)
class Album extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> poseImagePaths; // PoseModel.imagePath list

  @HiveField(3)
  DateTime createdAt;

  Album({
    required this.id,
    required this.name,
    required this.poseImagePaths,
    required this.createdAt,
  });
}
