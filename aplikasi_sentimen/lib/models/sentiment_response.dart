/// Model data untuk respons prediksi sentimen dari Flask API.
///
/// Memetakan JSON dari endpoint /api/predict ke objek Dart.
class SentimentResponse {
  final String sentiment;
  final double confidence;
  final Map<String, double> breakdown;

  SentimentResponse({
    required this.sentiment,
    required this.confidence,
    required this.breakdown,
  });

  factory SentimentResponse.fromJson(Map<String, dynamic> json) {
    final breakdownMap = (json['breakdown'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, (value as num).toDouble()));

    return SentimentResponse(
      sentiment: json['sentiment'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      breakdown: breakdownMap,
    );
  }
}
