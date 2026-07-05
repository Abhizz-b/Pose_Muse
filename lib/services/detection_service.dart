import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/scan_result.dart';

class DetectionService {
  static PoseDetector? _poseDetector;

  static PoseDetector get _detector {
    _poseDetector ??= PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
    return _poseDetector!;
  }

  // ── LIVENESS CHECK TUNING ──
  // Ye numbers starting point hain — real device pe test karke
  // adjust karne padenge.
  static const _liveGapMs = 400; // 2 frames ke beech gap
  static const _minGyroDeltaForCheck =
      0.03; // itna phone move na ho to check skip (inconclusive)
  static const _planarVarianceThreshold =
      0.0006; // isse kam variance = flat/screen suspect

  /// PURANA method — jahan pehle se use ho raha hai wahan ke liye
  /// as-is rakha hai, kisi aur jagah break na ho.
  static Future<ScanResult> analyze(CameraController cameraController) async {
    final isFront =
        cameraController.description.lensDirection == CameraLensDirection.front;

    XFile? frame;
    try {
      frame = await cameraController.takePicture();
      final inputImage = InputImage.fromFilePath(frame.path);
      final poses = await _detector.processImage(inputImage);

      if (poses.isEmpty) return ScanResult.noPerson;

      final landmarks = poses.first.landmarks;
      bool visible(PoseLandmarkType type) {
        final lm = landmarks[type];
        return lm != null && lm.likelihood > 0.6;
      }

      final hasCorePersonEvidence =
          visible(PoseLandmarkType.nose) ||
          (visible(PoseLandmarkType.leftShoulder) &&
              visible(PoseLandmarkType.rightShoulder));

      if (!hasCorePersonEvidence) return ScanResult.noPerson;

      if (isFront) return ScanResult.selfie;

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
      // ignore: avoid_print
      print('❌ DetectionService.analyze error: $e');
      // ignore: avoid_print
      print(stack);
      rethrow;
    } finally {
      if (frame != null) {
        final f = File(frame.path);
        if (await f.exists()) await f.delete();
      }
    }
  }

  /// NAYA method — isko home_screen se call karna hai ab.
  /// 2 frames leta hai thodi si gap ke saath, gyroscope se device
  /// movement track karta hai, aur landmarks ka displacement compare
  /// karke decide karta hai ki real 3D person hai ya flat screen/photo/video.
  static Future<ScanResult> analyzeLiveness(
    CameraController cameraController,
  ) async {
    final isFront =
        cameraController.description.lensDirection == CameraLensDirection.front;

    XFile? frame1;
    XFile? frame2;
    StreamSubscription<GyroscopeEvent>? gyroSub;
    double gyroDelta = 0;
    DateTime? lastTick;

    try {
      gyroSub = gyroscopeEventStream().listen((event) {
        final now = DateTime.now();
        if (lastTick != null) {
          final dt = now.difference(lastTick!).inMilliseconds / 1000.0;
          final mag = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          gyroDelta += mag * dt;
        }
        lastTick = now;
      });

      // ── FRAME 1 ──
      frame1 = await cameraController.takePicture();
      final poses1 = await _detector.processImage(
        InputImage.fromFilePath(frame1.path),
      );

      if (poses1.isEmpty) return ScanResult.noPerson;

      final landmarks1 = poses1.first.landmarks;
      bool visible1(PoseLandmarkType t) =>
          landmarks1[t] != null && landmarks1[t]!.likelihood > 0.75;

      final hasCoreEvidence1 =
          visible1(PoseLandmarkType.nose) ||
          (visible1(PoseLandmarkType.leftShoulder) &&
              visible1(PoseLandmarkType.rightShoulder));

      if (!hasCoreEvidence1) return ScanResult.noPerson;

      // ── WAIT ──
      await Future.delayed(const Duration(milliseconds: _liveGapMs));

      // ── FRAME 2 ──
      frame2 = await cameraController.takePicture();
      final poses2 = await _detector.processImage(
        InputImage.fromFilePath(frame2.path),
      );

      await gyroSub.cancel();
      gyroSub = null;

      // FIX: frame2 mein bhi person confirm hona zaroori hai — warna
      // ghost/noise wale false-positive frame1 detection ki wajah se
      // poora scan aage badh jaata tha bina real confirmation ke, aur
      // "No person detected" msg kabhi nahi dikhta tha.
      if (poses2.isEmpty) return ScanResult.noPerson;

      final landmarks2 = poses2.first.landmarks;
      bool visible2(PoseLandmarkType t) =>
          landmarks2[t] != null && landmarks2[t]!.likelihood > 0.75;

      final hasCoreEvidence2 =
          visible2(PoseLandmarkType.nose) ||
          (visible2(PoseLandmarkType.leftShoulder) &&
              visible2(PoseLandmarkType.rightShoulder));

      if (!hasCoreEvidence2) return ScanResult.noPerson;

      // FIX: selfie/front camera mein parallax check SKIP kar rahe hain.
      // Gyroscope sirf rotation measure karta hai, translation nahi —
      // aur parallax sirf translation se banta hai. Selfie lete waqt
      // phone zyada tilt/rotate hota hai, translate kam, isliye real
      // chehra bhi "flat/screen" jaisa dikh raha tha (false positive).
      // Face landmarks bhi ek hi depth range mein hote hain isliye ye
      // check yahan waise bhi unreliable hai.
      if (!isFront) {
        const candidates = [
          PoseLandmarkType.nose,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
        ];

        final displacements = <double>[];
        for (final type in candidates) {
          if (visible1(type) && visible2(type)) {
            final p1 = landmarks1[type]!;
            final p2 = landmarks2[type]!;
            final dx = p2.x - p1.x;
            final dy = p2.y - p1.y;
            displacements.add(sqrt(dx * dx + dy * dy));
          }
        }

        if (displacements.length >= 3 && gyroDelta > _minGyroDeltaForCheck) {
          final size = await _decodeSize(frame1.path);
          final diagonal = sqrt(
            size.width * size.width + size.height * size.height,
          );

          if (diagonal > 0) {
            final normalized = displacements.map((d) => d / diagonal).toList();
            final mean = normalized.reduce((a, b) => a + b) / normalized.length;
            final variance =
                normalized
                    .map((d) => (d - mean) * (d - mean))
                    .reduce((a, b) => a + b) /
                normalized.length;

            // ignore: avoid_print
            print(
              '🕵️ Liveness check — gyroDelta:$gyroDelta variance:$variance mean:$mean',
            );

            if (variance < _planarVarianceThreshold) {
              return ScanResult.screenDetected;
            }
          }
        }
      }

      // ── NORMAL FLOW — frame1 ke landmarks se full body/selfie decide ──
      if (isFront) return ScanResult.selfie;

      final fullBodyVisible =
          visible1(PoseLandmarkType.leftAnkle) &&
          visible1(PoseLandmarkType.rightAnkle) &&
          visible1(PoseLandmarkType.leftKnee) &&
          visible1(PoseLandmarkType.rightKnee) &&
          visible1(PoseLandmarkType.leftHip) &&
          visible1(PoseLandmarkType.rightHip) &&
          visible1(PoseLandmarkType.leftShoulder) &&
          visible1(PoseLandmarkType.rightShoulder);

      return fullBodyVisible ? ScanResult.fullBody : ScanResult.selfie;
    } catch (e, stack) {
      // ignore: avoid_print
      print('❌ DetectionService.analyzeLiveness error: $e');
      // ignore: avoid_print
      print(stack);
      rethrow;
    } finally {
      await gyroSub?.cancel();
      if (frame1 != null) {
        final f = File(frame1.path);
        if (await f.exists()) await f.delete();
      }
      if (frame2 != null) {
        final f = File(frame2.path);
        if (await f.exists()) await f.delete();
      }
    }
  }

  static Future<ui.Size> _decodeSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    final decoded = await completer.future;
    return ui.Size(decoded.width.toDouble(), decoded.height.toDouble());
  }

  static void dispose() {
    _poseDetector?.close();
    _poseDetector = null;
  }
}
