import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pose_model.dart';
import '../models/detection_result.dart';
import 'api_config.dart';

class PoseService {
  static Future<DetectionResult> getPosesForEnvironment(
    String environment,
    bool personDetected,
  ) async {
    if (!personDetected) {
      return DetectionResult(
        environment: 'Unknown',
        lighting: 'Unknown',
        mood: 'Unknown',
        confidence: 0,
        poses: [],
        personDetected: false,
      );
    }

    try {
      final poses = await _fetchPosesFromGroq(environment);
      final meta = _environmentMeta[environment] ?? _environmentMeta['Park']!;
      return DetectionResult(
        environment: environment,
        lighting: meta['lighting']!,
        mood: meta['mood']!,
        confidence: meta['confidence'] as double,
        poses: poses,
        personDetected: true,
      );
    } catch (e) {
      // Fallback to mock data if API fails
      return _getMockResult(environment);
    }
  }

  static Future<List<PoseModel>> _fetchPosesFromGroq(String environment) async {
    final prompt =
        '''
You are a professional photography pose coach. 
The user is in a "$environment" environment.
Generate exactly 6 creative, specific pose recommendations for this environment.

Respond ONLY with a valid JSON array. No explanation, no markdown, just pure JSON.

Format:
[
  {
    "name": "Pose Name",
    "description": "One sentence description of how to do this pose in this specific environment",
    "difficulty": "Easy",
    "cameraAngle": "Front view",
    "emoji": "🎯"
  }
]

Rules:
- difficulty must be exactly: Easy, Medium, or Hard
- cameraAngle options: Front view, Side view, Low angle, High angle, Behind, Diagonal, Top-down, Wide angle, Close-up, Candid
- Make poses SPECIFIC to $environment environment
- Use relevant emojis
- Exactly 6 poses
''';

    final response = await http.post(
      Uri.parse(ApiConfig.groqBaseUrl),
      headers: {
        'Authorization': 'Bearer ${ApiConfig.groqApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': ApiConfig.groqModel,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.8,
        'max_tokens': 1000,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;

    // Clean response — remove any markdown if present
    final cleaned = content
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final List<dynamic> poseList = jsonDecode(cleaned);
    return poseList
        .map(
          (p) => PoseModel(
            name: p['name'] ?? 'Pose',
            description: p['description'] ?? '',
            difficulty: p['difficulty'] ?? 'Easy',
            cameraAngle: p['cameraAngle'] ?? 'Front view',
            emoji: p['emoji'] ?? '📸',
          ),
        )
        .toList();
  }

  // Fallback mock data if API fails
  static DetectionResult _getMockResult(String environment) {
    final meta = _environmentMeta[environment] ?? _environmentMeta['Park']!;
    final poses = _mockPoses[environment] ?? _mockPoses['Park']!;
    return DetectionResult(
      environment: environment,
      lighting: meta['lighting']!,
      mood: meta['mood']!,
      confidence: meta['confidence'] as double,
      poses: poses,
      personDetected: true,
    );
  }

  static const Map<String, dynamic> _environmentMeta = {
    'Bedroom': {
      'lighting': 'Soft & Warm',
      'mood': 'Cozy & Intimate',
      'confidence': 0.91,
    },
    'Cafe': {
      'lighting': 'Warm Ambient',
      'mood': 'Aesthetic & Artsy',
      'confidence': 0.88,
    },
    'Park': {
      'lighting': 'Natural Daylight',
      'mood': 'Fresh & Vibrant',
      'confidence': 0.94,
    },
    'Beach': {
      'lighting': 'Bright & Glowy',
      'mood': 'Free & Adventurous',
      'confidence': 0.96,
    },
    'Office': {
      'lighting': 'Cool & Professional',
      'mood': 'Confident & Sharp',
      'confidence': 0.87,
    },
    'Street': {
      'lighting': 'Urban & Dynamic',
      'mood': 'Bold & Editorial',
      'confidence': 0.89,
    },
    'Library': {
      'lighting': 'Soft & Scholarly',
      'mood': 'Intellectual & Calm',
      'confidence': 0.85,
    },
    'Rooftop': {
      'lighting': 'Golden & Dramatic',
      'mood': 'Epic & Cinematic',
      'confidence': 0.93,
    },
  };

  static final Map<String, List<PoseModel>> _mockPoses = {
    'Park': [
      PoseModel(
        name: 'Golden Hour Walk',
        description: 'Walk naturally away from camera during golden hour',
        difficulty: 'Easy',
        cameraAngle: 'Behind',
        emoji: '🌇',
      ),
      PoseModel(
        name: 'Tree Lean',
        description: 'Lean casually against a tree with relaxed shoulders',
        difficulty: 'Easy',
        cameraAngle: 'Side view',
        emoji: '🌳',
      ),
      PoseModel(
        name: 'Grass Sit',
        description:
            'Sit cross-legged on grass with natural surrounding greenery',
        difficulty: 'Easy',
        cameraAngle: 'Low angle',
        emoji: '🍃',
      ),
      PoseModel(
        name: 'Jump Shot',
        description: 'Mid-air jump with arms out wide and big smile',
        difficulty: 'Hard',
        cameraAngle: 'Front view',
        emoji: '🦅',
      ),
      PoseModel(
        name: 'Path Stroll',
        description: 'Walk down a long path looking back over your shoulder',
        difficulty: 'Medium',
        cameraAngle: 'Wide angle',
        emoji: '🛤️',
      ),
      PoseModel(
        name: 'Flower Frame',
        description:
            'Use nearby flowers or plants to naturally frame your face',
        difficulty: 'Medium',
        cameraAngle: 'Close-up',
        emoji: '🌸',
      ),
    ],
  };
}
