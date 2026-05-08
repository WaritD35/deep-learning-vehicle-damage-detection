import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/damage_models.dart';
import '../services/api_service.dart';
import '../services/assessment_state.dart';
import 'results_screen.dart';
import 'settings_screen.dart';
import 'video_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final Map<String, SavedAssessmentSession> _sessionDetails = {};

  List<AssessmentHistoryItem> _history = [];
  bool _isLoading = true;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected = await context.read<ApiService>().healthCheck();
    if (mounted) {
      setState(() => _isConnected = connected);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('assessment_history') ?? [];
      final loaded = <AssessmentHistoryItem>[];

      for (final itemJson in historyJson) {
        try {
          loaded.add(AssessmentHistoryItem.fromJson(jsonDecode(itemJson)));
        } catch (e) {
          debugPrint('Skipping invalid history item: $e');
        }
      }

      loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _history = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteItem(AssessmentHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('assessment_history') ?? [];

    historyJson.removeWhere((json) {
      try {
        return AssessmentHistoryItem.fromJson(jsonDecode(json)).id == item.id;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList('assessment_history', historyJson);
    _sessionDetails.remove(item.id);
    await _loadHistory();
  }

  void _rememberSavedSession(SavedAssessmentSession? session) {
    if (session == null) return;
    _sessionDetails[session.historyItem.id] = session;
    _loadHistory();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name;
      if (mounted) {
        context.read<AssessmentState>().setImageBytes(bytes, filename);
        _analyzeImageBytes(bytes, filename);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickUploadMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'mp4',
          'mov',
          'avi',
          'mkv',
          'webm',
        ],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read the selected file')),
          );
        }
        return;
      }

      final extension = file.extension?.toLowerCase() ??
          file.name.split('.').last.toLowerCase();
      final isVideo = {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(extension);

      if (mounted) {
        final state = context.read<AssessmentState>();
        if (isVideo) {
          state.setVideoBytes(bytes, file.name);
          _analyzeVideo(bytes, file.name);
        } else {
          state.setImageBytes(bytes, file.name);
          _analyzeImageBytes(bytes, file.name);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error choosing file: $e')),
        );
      }
    }
  }

  Future<void> _analyzeImageBytes(Uint8List bytes, String filename) async {
    final api = context.read<ApiService>();
    final state = context.read<AssessmentState>();
    final prefs = await SharedPreferences.getInstance();
    final confThreshold = prefs.getDouble('confidence_threshold') ?? 0.25;
    final returnAnnotated = prefs.getBool('return_annotated') ?? true;
    final includeLabor = prefs.getBool('include_labor') ?? true;
    final currency = prefs.getString('currency') ?? 'AUD';

    try {
      state.setStatus(AssessmentStatus.analyzing, message: 'Analyzing image...');
      final detectionResult = await api.detectDamageBytes(
        bytes: bytes,
        filename: filename,
        confThreshold: confThreshold,
        returnAnnotated: returnAnnotated,
      );
      state.setDetectionResult(detectionResult);

      if (detectionResult.numDetections > 0) {
        state.setStatus(AssessmentStatus.estimatingCost, message: 'Estimating costs...');
        final costResult = await api.estimateCost(
          detections: detectionResult.detections,
          includeLabor: includeLabor,
          currency: currency,
        );
        state.setCostEstimation(costResult);

        state.setStatus(AssessmentStatus.generatingReport, message: 'Generating report...');
        final reportResult = await api.generateReport(
          detections: detectionResult.detections,
          costEstimation: costResult,
        );
        state.setReport(reportResult);
      } else {
        state.setStatus(AssessmentStatus.generatingReport, message: 'Generating report...');
        final reportResult = await api.generateReport(detections: []);
        state.setReport(reportResult);
      }

      if (mounted) {
        final savedSession = await Navigator.of(context).push<SavedAssessmentSession>(
          MaterialPageRoute(builder: (_) => const ResultsScreen()),
        );
        _rememberSavedSession(savedSession);
        if (savedSession != null) {
          state.clear();
        }
      }
    } catch (e) {
      state.setError('Analysis failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _analyzeVideo(Uint8List bytes, String filename) async {
    final api = context.read<ApiService>();
    final state = context.read<AssessmentState>();
    final prefs = await SharedPreferences.getInstance();
    final confThreshold = prefs.getDouble('confidence_threshold') ?? 0.25;
    final includeLabor = prefs.getBool('include_labor') ?? true;
    final currency = prefs.getString('currency') ?? 'AUD';

    try {
      state.setStatus(AssessmentStatus.analyzing, message: 'Processing video...');
      final videoResult = await api.detectDamageVideoBytes(
        bytes: bytes,
        filename: filename,
        confThreshold: confThreshold,
        frameInterval: 30,
        maxFrames: 50,
      );
      state.setVideoResult(videoResult);

      state.setStatus(AssessmentStatus.estimatingCost, message: 'Estimating costs...');
      final costResult = await api.estimateCost(
        detections: videoResult.aggregatedDetections,
        includeLabor: includeLabor,
        currency: currency,
      );
      state.setCostEstimation(costResult);

      state.setStatus(AssessmentStatus.generatingReport, message: 'Generating report...');
      final reportResult = await api.generateReport(
        detections: videoResult.aggregatedDetections,
        costEstimation: costResult,
      );
      state.setReport(reportResult);
      state.setStatus(
        AssessmentStatus.complete,
        message: videoResult.uniqueDetections > 0
            ? 'Analysis complete'
            : 'No damage detected in video',
      );

      if (mounted) {
        final savedSession = await Navigator.of(context).push<SavedAssessmentSession>(
          MaterialPageRoute(
            builder: (_) => VideoResultsScreen(
              videoResult: videoResult,
              costResult: costResult,
              reportResult: reportResult,
              videoBytes: bytes,
            ),
          ),
        );
        _rememberSavedSession(savedSession);
        if (savedSession != null) {
          state.clear();
        }
      }
    } catch (e) {
      state.setError('Video analysis failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showUploadOptions() {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server unavailable. Check the backend connection first.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        const purple = Color(0xFF5061C8);

        Color sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
        Color headerText = isDark ? Colors.white : const Color(0xFF0F172A);

        Widget option({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.14) : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? purple.withOpacity(0.35) : purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: isDark ? Colors.white : purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: headerText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white70 : purple,
                  ),
                ],
              ),
            ),
          );
        }

        return Dialog(
          alignment: Alignment.bottomRight,
          insetPadding: const EdgeInsets.fromLTRB(24, 24, 24, 92),
          backgroundColor: Colors.transparent,
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.10) : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take Photo',
                  subtitle: 'Open camera for damage analysis',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                option(
                  icon: Icons.upload_file_outlined,
                  title: 'Upload Media',
                  subtitle: 'Choose a photo or video',
                  onTap: () {
                    Navigator.pop(context);
                    _pickUploadMedia();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openHistoryItem(AssessmentHistoryItem item) {
    final session = _sessionDetails[item.id];
    if (session != null) {
      if (item.mediaType == AssessmentMediaType.video &&
          session.videoResult != null &&
          session.costResult != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoResultsScreen(
              videoResult: session.videoResult!,
              costResult: session.costResult!,
              reportResult: session.report,
              videoBytes: session.mediaBytes,
              initialTitle: item.title,
              readOnly: true,
            ),
          ),
        );
        return;
      }

      if (item.mediaType == AssessmentMediaType.image && session.detectionResult != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultsScreen(
              session: session,
              readOnly: true,
            ),
          ),
        );
        return;
      }
    }

    _showHistorySummary(item);
  }

  void _showHistorySummary(AssessmentHistoryItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${DateFormat('dd MMM yyyy - HH:mm').format(item.timestamp)}'),
            const SizedBox(height: 8),
            Text('Media: ${item.mediaType == AssessmentMediaType.video ? 'Video' : 'Image'}'),
            const SizedBox(height: 8),
            if (item.severity != null)
              Text(
                'Severity: ${item.severity!.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (item.damageTypes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Damage types:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...item.damageTypes.map((t) => Text('  - ${t.replaceAll("_", " ")}')),
            ],
            if (item.totalCost != null) ...[
              const SizedBox(height: 8),
              Text(
                'Est. Cost: \$${item.totalCost!.toStringAsFixed(2)} AUD',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AssessmentState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = Color(0xFF5061C8);

    final totalCost = _history.fold<double>(
      0,
      (sum, item) => sum + (item.totalCost ?? 0),
    );
    final totalDamages = _history.fold<int>(
      0,
      (sum, item) => sum + item.damageCount,
    );
    final severeCount = _history.where((i) => (i.severity ?? '').toLowerCase() == 'severe').length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFEAF3FA),
      body: SafeArea(
        child: Stack(
          children: [
            // Keep overscroll reveal aligned with header color at the top.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.32, 0.32, 1.0],
                    colors: [
                      purple,
                      purple,
                      isDark ? const Color(0xFF0B1220) : const Color(0xFFEAF3FA),
                      isDark ? const Color(0xFF0B1220) : const Color(0xFFEAF3FA),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              RefreshIndicator(
                onRefresh: _loadHistory,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _SketchHeader(
                      isDark: isDark,
                      isConnected: _isConnected,
                      totalAssessments: _history.length,
                      onSettingsTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      onReconnectTap: _checkConnection,
                    ),
                    Transform.translate(
                      offset: const Offset(0, -42),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 54),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF111827) : Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (_history.isNotEmpty) ...[
                                _SketchSummaryStrip(
                                  isDark: isDark,
                                  totalAssessments: _history.length,
                                  totalDamages: totalDamages,
                                  severeCount: severeCount,
                                  totalCost: totalCost,
                                ),
                              ],
                              const SizedBox(height: 18),
                              if (_history.isEmpty)
                                const _EmptyHistoryState()
                              else
                                ..._history.map(
                                  (item) => _HistoryCard(
                                    item: item,
                                    thumbnailBytes: _sessionDetails[item.id]?.mediaBytes,
                                    onTap: () => _openHistoryItem(item),
                                    onDelete: () => _deleteItem(item),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (state.isProcessing)
              Container(
                color: Colors.black.withOpacity(0.18),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(state.progressMessage),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        foregroundColor: purple,
        tooltip: 'Analyze vehicle damage',
        onPressed: state.isProcessing ? null : _showUploadOptions,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'nothing to show here',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            ':)',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AssessmentHistoryItem item;
  final Uint8List? thumbnailBytes;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.item,
    this.thumbnailBytes,
    required this.onTap,
    required this.onDelete,
  });

  String get _formattedDate {
    final diff = DateTime.now().difference(item.timestamp);
    if (diff.inDays == 0) return 'Today, ${DateFormat.jm().format(item.timestamp)}';
    if (diff.inDays == 1) return 'Yesterday, ${DateFormat.jm().format(item.timestamp)}';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat.yMMMd().format(item.timestamp);
  }

  Color _severityColor(BuildContext context) {
    switch (item.severity?.toLowerCase()) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'minor':
        return Colors.amber;
      case 'none':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 78,
                  height: 64,
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    border: Border.all(color: severityColor.withOpacity(0.25)),
                  ),
                  child: thumbnailBytes != null
                      ? Image.memory(
                          thumbnailBytes!,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          item.mediaType == AssessmentMediaType.video
                              ? Icons.videocam_outlined
                              : Icons.directions_car_outlined,
                          color: severityColor,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formattedDate,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.damageCount} damage${item.damageCount == 1 ? '' : 's'} detected',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    if (item.damageTypes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: item.damageTypes.take(3).map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                              ),
                            ),
                            child: Text(
                              t.replaceAll('_', ' '),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_right_rounded),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SketchHeader extends StatelessWidget {
  final bool isDark;
  final bool isConnected;
  final int totalAssessments;
  final VoidCallback onReconnectTap;
  final VoidCallback onSettingsTap;

  const _SketchHeader({
    required this.isDark,
    required this.isConnected,
    required this.totalAssessments,
    required this.onReconnectTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF5061C8);

    return Container(
      // No fixed height — let the column determine size so it never overflows.
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 52),
      decoration: const BoxDecoration(
        color: purple,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onReconnectTap,
                tooltip: isConnected ? 'Connected to server' : 'Reconnect',
                icon: Icon(
                  isConnected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onSettingsTap,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.24)),
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'My assessments',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.82),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Damage reports',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$totalAssessments',
                      style: const TextStyle(
                        color: purple,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'reports',
                      style: TextStyle(color: purple, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SketchSummaryStrip extends StatelessWidget {
  final bool isDark;
  final int totalAssessments;
  final int totalDamages;
  final int severeCount;
  final double totalCost;

  const _SketchSummaryStrip({
    required this.isDark,
    required this.totalAssessments,
    required this.totalDamages,
    required this.severeCount,
    required this.totalCost,
  });

  @override
  Widget build(BuildContext context) {
    Widget item(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final tiles = [
      item('Reports', '$totalAssessments'),
      item('Damage', '$totalDamages'),
      item('Severe', '$severeCount'),
      item('Cost', totalCost > 0 ? '\$${totalCost.toStringAsFixed(0)}' : '-'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        if (constraints.maxWidth < 500) {
          final tileWidth = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: tiles
                .map((w) => SizedBox(width: tileWidth, child: w))
                .toList(growable: false),
          );
        }

        return Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: gap),
            Expanded(child: tiles[1]),
            const SizedBox(width: gap),
            Expanded(child: tiles[2]),
            const SizedBox(width: gap),
            Expanded(child: tiles[3]),
          ],
        );
      },
    );
  }
}

