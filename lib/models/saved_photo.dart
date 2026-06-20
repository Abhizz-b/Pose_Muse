class SavedPhoto {
  final String id; // unique id, also used as filename (without extension)
  final String path; // full file path on device, inside app's local storage
  final DateTime takenAt;
  bool isFavourite;

  SavedPhoto({
    required this.id,
    required this.path,
    required this.takenAt,
    this.isFavourite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'takenAt': takenAt.toIso8601String(),
    'isFavourite': isFavourite,
  };

  factory SavedPhoto.fromJson(Map<String, dynamic> json) => SavedPhoto(
    id: json['id'],
    path: json['path'],
    takenAt: DateTime.parse(json['takenAt']),
    isFavourite: json['isFavourite'] ?? false,
  );
}
