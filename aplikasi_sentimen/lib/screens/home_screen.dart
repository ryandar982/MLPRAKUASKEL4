import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ModelInfoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.analytics,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'FinBERT Analyzer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline),
              activeIcon: Icon(Icons.info),
              label: 'Tentang Model',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _hasResult = false;
  String _errorMessage = '';

  String _sentiment = '';
  double _confidence = 0;
  Map<String, double> _breakdown = {};

  final List<_HistoryEntry> _history = [];
  
  bool _isRolling = false;
  String _currentRollingSentiment = 'Netral';
  Timer? _rollingTimer;
  late AnimationController _popController;
  late Animation<double> _popAnimation;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _popAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
    ]).animate(_popController);
  }

  @override
  void dispose() {
    _rollingTimer?.cancel();
    _popController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyzeSentiment() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan masukkan teks terlebih dahulu'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasResult = false;
      _errorMessage = '';
    });

    try {
      final response = await _apiService.predictSentiment(text);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasResult = true;
        _isRolling = true;
        
        _sentiment = response.sentiment;
        _confidence = response.confidence;
        _breakdown = response.breakdown;
      });

      final states = ['positive', 'negative', 'neutral'];
      int rollingIndex = 0;
      
      _rollingTimer?.cancel();
      _rollingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
           timer.cancel();
           return;
        }
        setState(() {
          _currentRollingSentiment = states[rollingIndex % states.length];
        });
        rollingIndex++;
      });
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _rollingTimer?.cancel();
        setState(() {
          _isRolling = false;
        });
        _popController.forward(from: 0.0);
        
        _history.insert(0, _HistoryEntry(
          text: text,
          sentiment: response.sentiment,
          confidence: response.confidence,
          timestamp: DateTime.now(),
        ));
        if (_history.length > 20) _history.removeLast();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal terhubung ke server.\n$e';
      });
    }
  }

  Color _getSentimentColor(String sentiment) {
    final s = sentiment.toLowerCase();
    if (s.contains('positive')) return const Color(0xFF10B981); // Emerald
    if (s.contains('negative')) return const Color(0xFFEF4444); // Red
    return const Color(0xFFF59E0B); // Amber
  }

  String _getSentimentLabel(String sentiment) {
    final s = sentiment.toLowerCase();
    if (s.contains('positive')) return 'Positif';
    if (s.contains('negative')) return 'Negatif';
    return 'Netral';
  }

  IconData _getSentimentIcon(String sentiment) {
    final s = sentiment.toLowerCase();
    if (s.contains('positive')) return Icons.sentiment_satisfied;
    if (s.contains('negative')) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_neutral;
  }

  @override
  Widget build(BuildContext context) {
    final displaySentiment = _isRolling ? _currentRollingSentiment : _sentiment;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero Banner + Overlapping Avatar (like food delivery app) ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: Image.asset(
                  'assets/images/hero_banner.png',
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              // Dark gradient overlay for readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.45),
                      ],
                    ),
                  ),
                ),
              ),
              // Overlapping mascot avatar
              Positioned(
                bottom: -36,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/berti.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 44), // space for the overlapping avatar

          // ── Title & Subtitle ──
          const Text(
            'FinBERT Analyzer',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Asisten Analisis Sentimen AI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blueGrey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),

          // ── Info chips row (like rating, open hours, min order) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                const SizedBox(width: 4),
                const Text(
                  'FinBERT',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                Text(' · ', style: TextStyle(color: Colors.blueGrey.shade300)),
                Icon(Icons.circle, size: 6, color: Colors.green.shade400),
                const SizedBox(width: 4),
                Text(
                  'Online',
                  style: TextStyle(fontSize: 13, color: Colors.green.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Action chips (like Delivery 30-40 min, icons) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Prediksi Instan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Promo-style description card ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tips_and_updates, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ketik teks di bawah dan aku akan analisis sentimennya pakai kekuatan FinBERT!',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF065F46), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Input Card ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: Colors.blueGrey.shade400),
                      const SizedBox(width: 8),
                      const Text(
                        'Masukkan Teks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Ketik atau tempel teks finansial di sini...',
                      hintStyle: TextStyle(color: Colors.blueGrey.shade300),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blueGrey.shade100),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blueGrey.shade100),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _analyzeSentiment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Analisis Teks',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          if (_hasResult) ...[
            // (existing result container is retained correctly by not modifying it, just appending below)
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getSentimentColor(_sentiment).withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: _getSentimentColor(_sentiment).withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Hasil Prediksi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ScaleTransition(
                      scale: _isRolling ? const AlwaysStoppedAnimation(1.0) : _popAnimation,
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _getSentimentColor(displaySentiment).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getSentimentIcon(displaySentiment),
                              color: _getSentimentColor(displaySentiment),
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getSentimentLabel(displaySentiment),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _getSentimentColor(displaySentiment),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!_isRolling)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blueGrey.shade700,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 30), // Placeholder agar layout tidak loncat
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    if (!_isRolling) ...[
                      const Divider(height: 1),
                      const SizedBox(height: 24),
                      
                      // Breakdown Pie Chart
                      Text(
                        'Distribusi Sentimen',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade400,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 50,
                                sections: [
                                  ..._breakdown.entries.map((e) {
                                    final color = _getSentimentColor(e.key);
                                    final realValue = e.value * 100;
                                    final renderValue = realValue * value;
                                    
                                    return PieChartSectionData(
                                      color: color,
                                      value: renderValue,
                                      title: value > 0.3 && realValue > 5 
                                          ? '${renderValue.toStringAsFixed(1)}%' 
                                          : '',
                                      radius: 50 + (10 * value), // Grows slightly
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }),
                                  // Empty background section that shrinks as animation progresses
                                  if (value < 1.0)
                                    PieChartSectionData(
                                      color: Colors.blueGrey.shade50,
                                      value: 100 - (100 * value),
                                      title: '',
                                      radius: 50 + (10 * value),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Legends
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: _breakdown.entries.map((e) {
                          final color = _getSentimentColor(e.key);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_getSentimentLabel(e.key)} (${(e.value * 100).toStringAsFixed(1)}%)',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Analisis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _history.clear()),
                    child: const Text('Hapus', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._history.map((entry) {
              final color = _getSentimentColor(entry.sentiment);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getSentimentIcon(entry.sentiment), color: color, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_getSentimentLabel(entry.sentiment)} • ${(entry.confidence * 100).toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class ModelInfoScreen extends StatelessWidget {
  const ModelInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.model_training, color: Colors.indigo.shade600, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Tentang FinBERT',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'FinBERT adalah model bahasa pre-trained berbasis arsitektur BERT yang telah disesuaikan secara khusus pada dataset finansial.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Keunggulan Utama',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(Icons.psychology, 'Pemahaman Konteks', 'Mampu memahami nuansa dan istilah khusus dalam dokumen keuangan dan ekonomi.'),
              _buildFeatureItem(Icons.analytics, 'Akurasi Tinggi', 'Dirancang khusus untuk membedakan sentimen Positif, Negatif, dan Netral di sektor bisnis.'),
              _buildFeatureItem(Icons.speed, 'Pemrosesan Cepat', 'Dioptimasi untuk inference yang efisien menggunakan library transformers modern.'),
              
              const SizedBox(height: 32),
              const Divider(height: 1),
              const SizedBox(height: 24),
              
              const Text(
                'Cara Kerja Analisis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              _buildStepItem('1', 'Teks Diinput', 'Pengguna memasukkan paragraf atau kalimat.'),
              _buildStepItem('2', 'Tokenisasi', 'Teks dipecah menjadi token yang dapat dibaca oleh FinBERT.'),
              _buildStepItem('3', 'Inference API', 'Teks diproses oleh server Flask menggunakan model Machine Learning.'),
              _buildStepItem('4', 'Hasil Klasifikasi', 'Aplikasi menampilkan persentase kemungkinan tiap kategori sentimen.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntry {
  final String text;
  final String sentiment;
  final double confidence;
  final DateTime timestamp;

  _HistoryEntry({
    required this.text,
    required this.sentiment,
    required this.confidence,
    required this.timestamp,
  });
}
