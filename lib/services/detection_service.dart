import 'dart:math';
import '../models/detection_result.dart';
import 'pose_service.dart';

class DetectionService {
  static bool _isAnalyzing = false;

  static Future<bool> detectPerson(dynamic image, dynamic camera) async {
    // Always return true — skip ML Kit, Groq handles everything
    return true;
  }

  static Future<DetectionResult> analyze(dynamic image, dynamic camera) async {
    if (_isAnalyzing) {
      return DetectionResult(
        environment: 'Unknown',
        lighting: 'Unknown',
        mood: 'Unknown',
        confidence: 0,
        poses: [],
        personDetected: false,
      );
    }
    _isAnalyzing = true;
    try {
      final environments = [
        'Bedroom',
        'Cafe',
        'Park',
        'Beach',
        'Office',
        'Street',
        'Library',
        'Rooftop',
      ];
      final env = environments[Random().nextInt(environments.length)];
      final result = await PoseService.getPosesForEnvironment(env, true);
      return result;
    } finally {
      _isAnalyzing = false;
    }
  }

  static void dispose() {}
}
