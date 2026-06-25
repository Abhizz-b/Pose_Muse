import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Calls the remove.bg API to turn a picked photo into a transparent-
/// background cutout, and saves the result as a local PNG file.
///
/// Add to pubspec.yaml:
///   http: ^1.2.0
///   path_provider: ^2.1.0
class BackgroundRemovalService {
  // TODO: move this off the client (e.g. behind a Firebase Cloud Function)
  // before shipping to real users — a hardcoded key in the app binary can
  // be extracted. Fine for now while you're wiring the flow end-to-end.
  static const String _apiKey = 'uUy9DGkm7NVA4Yzv425eEGz8';

  static Future<File> removeBackground(File sourceImage) async {
    final uri = Uri.parse('https://api.remove.bg/v1.0/removebg');

    final request = http.MultipartRequest('POST', uri)
      ..headers['X-Api-Key'] = _apiKey
      ..fields['size'] = 'auto'
      ..files.add(
        await http.MultipartFile.fromPath('image_file', sourceImage.path),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      // 402 = free-tier limit hit, 400 = no clear foreground found, etc.
      throw Exception(
        'remove.bg failed (${response.statusCode}): ${response.body}',
      );
    }

    final dir = await getTemporaryDirectory();
    final outFile = File(
      '${dir.path}/cutout_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await outFile.writeAsBytes(response.bodyBytes);
    return outFile;
  }
}

/// --- Example wiring inside your parent screen (not this file) ---
///
/// final List<File> _processingPoses = [];
///
/// Future<void> _handleAddPose() async {
///   final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
///   if (picked == null) return;
///   final file = File(picked.path);
///
///   setState(() => _processingPoses.add(file));
///
///   try {
///     final cutout = await BackgroundRemovalService.removeBackground(file);
///     setState(() {
///       _processingPoses.remove(file);
///       _poses.add(PoseModel(imagePath: cutout.path /* + your other fields */));
///     });
///     // TODO: also upload `cutout` to Firebase Storage + save metadata in
///     // Firestore once that step of the plan is reached.
///   } catch (e) {
///     setState(() => _processingPoses.remove(file));
///     // TODO: show a snackbar/toast with the error.
///   }
/// }
