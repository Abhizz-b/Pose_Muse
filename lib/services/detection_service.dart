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
    // FIX: pehle front camera pe detection bilkul skip ho jaata tha aur
    // hamesha ScanResult.selfie return hota tha — chahe frame mein koi
    // ho ya na ho. Ab front camera pe bhi wahi real pose-check chalega
    // jo back camera pe chalta hai, bas fullBody requirement front
    // camera ke liye relax kar denge (selfie mein legs dikhna normal
    // nahi hota).
    final isFront =
        cameraController.description.lensDirection == CameraLensDirection.front;

    XFile? frame;
    try {
      // ignore: avoid_print
      print('🔍 [1/3] takePicture() shuru...');
      frame = await cameraController.takePicture();
      // ignore: avoid_print
      print('🔍 [1/3] takePicture() done: ${frame.path}');

      final inputImage = InputImage.fromFilePath(frame.path);
      // ignore: avoid_print
      print('🔍 [2/3] processImage() shuru...');
      final poses = await _detector.processImage(inputImage);
      // ignore: avoid_print
      print('🔍 [2/3] processImage() done. Poses found: ${poses.length}');

      if (poses.isEmpty) {
        // ignore: avoid_print
        print('🔍 [3/3] Result: noPerson (poses list khaali)');
        return ScanResult.noPerson;
      }

      final landmarks = poses.first.landmarks;
      bool visible(PoseLandmarkType type) {
        final lm = landmarks[type];
        return lm != null && lm.likelihood > 0.6;
      }

      // FIX (false positive): ML Kit kabhi kabhi ek "pose" object
      // return kar deta hai jisme landmarks map non-empty hoti hai
      // lekin sab landmarks ka likelihood bahut low hota hai (koi
      // real subject nahi, bas noise/shadow se ek ghost pose ban
      // jaata hai). Pehle code seedha isko bhi "selfie" maan leta
      // tha kyunki sirf poses.isEmpty check ho raha tha.
      // Ab hum minimum core evidence maangte hain — nose ya dono
      // shoulders reliably (>0.6 likelihood) dikhne chahiye, tabhi
      // "person hai" maanenge. Warna noPerson.
      final hasCorePersonEvidence =
          visible(PoseLandmarkType.nose) ||
          (visible(PoseLandmarkType.leftShoulder) &&
              visible(PoseLandmarkType.rightShoulder));

      // ignore: avoid_print
      print('🔍 [3/3] hasCorePersonEvidence: $hasCorePersonEvidence');

      if (!hasCorePersonEvidence) {
        // ignore: avoid_print
        print('🔍 [3/3] Result: noPerson (core evidence weak/missing)');
        return ScanResult.noPerson;
      }

      if (isFront) {
        // Selfie mein full body ki zaroorat nahi — core evidence
        // (face/shoulders) mil gaya matlab person hai.
        // ignore: avoid_print
        print('🔍 [3/3] Result: selfie (front camera)');
        return ScanResult.selfie;
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
    } catch (e, stack) {
      // Detection ya capture fail hua — ML Kit setup issue, permission
      // issue, ya camera busy hona (common causes) print kar rahe hain
      // taaki debug karna aasan ho. Ye function ab exception rethrow
      // karta hai — caller (home_screen) usko catch karega aur
      // noPerson maan lega, lekin ab error visible hoga console mein.
      // ignore: avoid_print
      print('❌ DetectionService error: $e');
      // ignore: avoid_print
      print(stack);
      rethrow;
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
