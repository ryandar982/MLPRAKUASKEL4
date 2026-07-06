import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sentiment_response.dart';

/// Service untuk komunikasi HTTP ke Flask API FinBERT.
///
/// Ganti [baseUrl] sesuai lingkungan pengujian Anda:
/// - Flutter Web / Desktop di laptop yang sama: http://127.0.0.1:5000
/// - Emulator Android: http://10.0.2.2:5000
/// - HP Fisik via WiFi: http://<IP_LAPTOP>:5000
class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000';

  /// Mengirim teks ke endpoint /api/predict untuk prediksi sentimen FinBERT.
  Future<SentimentResponse> predictSentiment(String text) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/predict'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'text': text}),
    );

    if (response.statusCode == 200) {
      return SentimentResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }
}
