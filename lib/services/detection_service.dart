import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/scan_result.dart';

class DetectionService {
  static PoseDetector? _poseDetector;

  static PoseDetector get _detector {
    _poseDetector ??= PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
    return _poseDetector!;
  }

  static Future<ScanResult> analyze(CameraController cameraController) async {
    // Front camera = always selfie poses, skip detection entirely
    if (cameraController.description.lensDirection ==
        CameraLensDirection.front) {
      return ScanResult.selfie;
    }

    // Back camera = capture a frame and check body landmarks
    XFile? frame;
    try {
      frame = await cameraController.takePicture();
      final inputImage = InputImage.fromFilePath(frame.path);
      final poses = await _detector.processImage(inputImage);

      if (poses.isEmpty) {
        return ScanResult.noPerson;
      }

      final landmarks = poses.first.landmarks;
      bool visible(PoseLandmarkType type) {
        final lm = landmarks[type];
        return lm != null && lm.likelihood > 0.6;
      }

      final fullBodyVisible =
          visible(PoseLandmarkType.leftAnkle) &&
          visible(PoseLandmarkType.rightAnkle) &&
          visible(PoseLandmarkType.leftKnee) &&
          visible(PoseLandmarkType.rightKnee) &&
          visible(PoseLandmarkType.leftHip) &&
          visible(PoseLandmarkType.rightHip) &&
          visible(PoseLandmarkType.leftShoulder) &&
          visible(PoseLandmarkType.rightShoulder);

      return fullBodyVisible ? ScanResult.fullBody : ScanResult.selfie;
    } finally {
      // Delete the temp scan frame — don't clutter the user's gallery
      if (frame != null) {
        final f = File(frame.path);
        if (await f.exists()) await f.delete();
      }
    }
  }

  static void dispose() {
    _poseDetector?.close();
    _poseDetector = null;
  }
}
