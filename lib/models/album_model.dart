import 'package:cloud_firestore/cloud_firestore.dart';

class Album {
  String id;
  String name;
  List<String> poseImagePaths;
  DateTime createdAt;

  Album({
    required this.id,
    required this.name,
    required this.poseImagePaths,
    required this.createdAt,
  });

  factory Album.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Album(
      id: doc.id,
      name: data['name'] ?? '',
      poseImagePaths: List<String>.from(data['poseImagePaths'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'poseImagePaths': poseImagePaths,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
