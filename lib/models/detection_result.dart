import 'pose_model.dart';

class DetectionResult {
  final String environment;
  final String lighting;
  final String mood;
  final double confidence;
  final List<PoseModel> poses;
  final bool personDetected;

  DetectionResult({
    required this.environment,
    required this.lighting,
    required this.mood,
    required this.confidence,
    required this.poses,
    required this.personDetected,
  });
}
