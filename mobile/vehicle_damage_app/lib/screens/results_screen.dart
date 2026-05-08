import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/damage_models.dart';
import '../services/assessment_state.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class ResultsScreen extends StatefulWidget {
  final SavedAssessmentSession? session;
  final bool readOnly;

  const ResultsScreen({
    super.key,
    this.session,
    this.readOnly = false,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final TextEditingController _titleController;
  late String _savedTitle;
  bool _isSaving = false;
  bool _isCopyPressed = false;
  bool _isCopySuccess = false;

  @override
  void initState() {
    super.initState();
    _savedTitle = widget.session?.historyItem.title ?? 'Untitled';
    _titleController = TextEditingController(
      text: _savedTitle,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveAssessment({
    required AssessmentState state,
    required DamageDetectionResponse detectionResult,
    required CostEstimationResponse? costResult,
    required ReportResponse? report,
  }) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled'
        : _titleController.text.trim();
    final historyItem = AssessmentHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      timestamp: DateTime.now(),
      mediaType: AssessmentMediaType.image,
      damageCount: detectionResult.numDetections,
      damageTypes: detectionResult.detections.map((d) => d.className).toSet().toList(),
      totalCost: costResult?.totalCost,
      severity: report?.assessmentSummary.overallSeverity ??
          (detectionResult.numDetections == 0 ? 'none' : null),
    );

    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('assessment_history') ?? [];
    historyJson.insert(0, jsonEncode(historyItem.toJson()));
    if (historyJson.length > 50) {
      historyJson.removeRange(50, historyJson.length);
    }
    await prefs.setStringList('assessment_history', historyJson);

    state.setAssessmentTitle(title);

    if (!mounted) return;
    Navigator.of(context).pop(
      SavedAssessmentSession(
        historyItem: historyItem,
        mediaBytes: state.imageBytes,
        detectionResult: detectionResult,
        costResult: costResult,
        report: report,
      ),
    );
  }

  String get _normalizedTitle {
    final title = _titleController.text.trim();
    return title.isEmpty ? 'Untitled' : title;
  }

  bool get _hasEditedTitle => _normalizedTitle != _savedTitle;

  Future<void> _saveEditedTitle() async {
    if (_isSaving || !_hasEditedTitle) return;
    final session = widget.session;
    if (session == null) return;

    final updatedTitle = _normalizedTitle;
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('assessment_history') ?? [];
    final updatedHistory = historyJson.map((itemJson) {
      try {
        final decoded = jsonDecode(itemJson) as Map<String, dynamic>;
        if ((decoded['id'] as String?) == session.historyItem.id) {
          decoded['title'] = updatedTitle;
        }
        return jsonEncode(decoded);
      } catch (_) {
        return itemJson;
      }
    }).toList(growable: false);
    await prefs.setStringList('assessment_history', updatedHistory);

    if (!mounted) return;
    setState(() {
      _savedTitle = updatedTitle;
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report title updated')),
    );
  }

  void _copyReport({
    required DamageDetectionResponse detectionResult,
    required CostEstimationResponse? costResult,
    required ReportResponse? report,
  }) {
    final buffer = StringBuffer()
      ..writeln('Vehicle Damage Assessment Report')
      ..writeln('Title: ${_titleController.text.trim().isEmpty ? 'Untitled' : _titleController.text.trim()}')
      ..writeln('');

    if (report != null) {
      buffer
        ..writeln('Severity: ${report.assessmentSummary.overallSeverity.toUpperCase()}')
        ..writeln('Summary: ${report.assessmentSummary.summaryText}')
        ..writeln('');
    }

    buffer.writeln('Detected damages (${detectionResult.numDetections}):');
    if (detectionResult.detections.isEmpty) {
      buffer.writeln('  - No damage detected');
    } else {
      for (final detection in detectionResult.detections) {
        buffer.writeln(
          '  - ${detection.className.replaceAll('_', ' ')} '
          '(${(detection.confidence * 100).toStringAsFixed(0)}% confidence'
          '${detection.severity != null ? ', ${detection.severity} severity' : ''})',
        );
      }
    }

    if (costResult != null) {
      buffer
        ..writeln('')
        ..writeln('Estimated Repair Cost (${costResult.currency}):')
        ..writeln('  Subtotal: \$${costResult.subtotal.toStringAsFixed(2)}')
        ..writeln('  GST (${(costResult.taxRate * 100).toStringAsFixed(0)}%): \$${costResult.taxAmount.toStringAsFixed(2)}')
        ..writeln('  Total: \$${costResult.totalCost.toStringAsFixed(2)}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied to clipboard')),
    );
  }

  Future<void> _handleCopyTap({
    required DamageDetectionResponse detectionResult,
    required CostEstimationResponse? costResult,
    required ReportResponse? report,
  }) async {
    setState(() => _isCopyPressed = true);
    _copyReport(
      detectionResult: detectionResult,
      costResult: costResult,
      report: report,
    );
    setState(() => _isCopySuccess = true);
    await Future<void>.delayed(const Duration(milliseconds: 170));
    if (mounted) {
      setState(() => _isCopyPressed = false);
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() => _isCopySuccess = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AssessmentState>();
    final session = widget.session;
    final detectionResult = session?.detectionResult ?? state.detectionResult;
    final costResult = session?.costResult ?? state.costEstimation;
    final report = session?.report ?? state.report;
    final mediaBytes = session?.mediaBytes ?? state.imageBytes;
    final annotatedImage = detectionResult?.annotatedImage;
    final shouldShowSaveButton = !widget.readOnly || _hasEditedTitle;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : AppTheme.backgroundColor,
      body: detectionResult == null
          ? const Center(child: Text('No results available'))
          : SafeArea(
              child: Column(
                children: [
                  Container(
                    height: 124,
                    color: const Color(0xFF5061C8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            'Analysis Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _HeaderIconAction(
                          icon: _isCopySuccess
                              ? Icons.assignment_turned_in_outlined
                              : Icons.copy_all_outlined,
                          tooltip: 'Copy report',
                          isPressed: _isCopyPressed,
                          onTap: () => _handleCopyTap(
                                detectionResult: detectionResult,
                                costResult: costResult,
                                report: report,
                              ),
                        ),
                        if (report != null)
                          const SizedBox(width: 8),
                        if (report != null)
                          _HeaderIconAction(
                            icon: Icons.chat_bubble_outline,
                            tooltip: 'Ask AI',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(assessmentId: report.reportId),
                                ),
                              );
                            },
                          ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -22),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131D33) : Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F3FB),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextField(
                                controller: _titleController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Untitled',
                                  suffixIcon: Icon(Icons.edit_outlined),
                                  border: OutlineInputBorder(borderSide: BorderSide.none),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                ),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _PreviewCard(
                              annotatedImage: annotatedImage,
                              mediaBytes: mediaBytes,
                              detections: detectionResult.detections,
                              imageSize: detectionResult.imageSize,
                            ),
                            const SizedBox(height: 18),
                            _AnalysisOverviewCard(
                              detectionResult: detectionResult,
                              costResult: costResult,
                              report: report,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Car part damage',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            if (detectionResult.detections.isEmpty)
                              const _NoDamageCard()
                            else
                              ...detectionResult.detections.asMap().entries.map(
                                    (entry) => _DamagePartCard(
                                      detection: entry.value,
                                      index: entry.key + 1,
                                    ),
                                  ),
                            if (shouldShowSaveButton) ...[
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : widget.readOnly
                                        ? _saveEditedTitle
                                        : () => _saveAssessment(
                                              state: state,
                                              detectionResult: detectionResult,
                                              costResult: costResult,
                                              report: report,
                                            ),
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('Save'),
                              ),
                            ],
                            if (costResult != null) ...[
                              const SizedBox(height: 16),
                              _CostSummaryCard(cost: costResult),
                            ],
                            if (report != null) ...[
                              const SizedBox(height: 16),
                              _ReportSummaryCard(summary: report.assessmentSummary),
                            ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String? annotatedImage;
  final Uint8List? mediaBytes;
  final List<Detection> detections;
  final Map<String, int>? imageSize;

  const _PreviewCard({
    required this.annotatedImage,
    required this.mediaBytes,
    required this.detections,
    required this.imageSize,
  });

  void _openImageModal(BuildContext context) {
    final hasImage = annotatedImage != null || mediaBytes != null;
    if (!hasImage) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width,
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Photo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: annotatedImage != null
                            ? Image.memory(
                                base64Decode(annotatedImage!),
                                fit: BoxFit.contain,
                              )
                            : Image.memory(
                                mediaBytes!,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = annotatedImage != null || mediaBytes != null;

    return Card(
      color: const Color(0xFFF4F3FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
          onTap: hasImage ? () => _openImageModal(context) : null,
          child: SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                annotatedImage != null
                    ? Image.memory(
                        base64Decode(annotatedImage!),
                        fit: BoxFit.cover,
                      )
                    : (mediaBytes != null
                        ? Image.memory(
                            mediaBytes!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: const Icon(
                              Icons.directions_car_outlined,
                              size: 56,
                            ),
                          )),
                // If backend returns an "annotated_image", boxes are already drawn.
                // Otherwise we overlay bbox rectangles so users still see the damaged areas.
                if (annotatedImage == null &&
                    mediaBytes != null &&
                    detections.isNotEmpty &&
                    (imageSize?['width'] ?? 0) > 0 &&
                    (imageSize?['height'] ?? 0) > 0)
                  CustomPaint(
                    painter: _DamageBboxOverlayPainter(
                      detections: detections,
                      imageWidth: (imageSize!['width'] ?? 0).toDouble(),
                      imageHeight: (imageSize!['height'] ?? 0).toDouble(),
                    ),
                  ),
                if (hasImage)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.zoom_in, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Tap to view',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ),
    );
  }
}

class _HeaderIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isPressed;

  const _HeaderIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isPressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isPressed
                ? Colors.white.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isPressed
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.24),
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _DamageBboxOverlayPainter extends CustomPainter {
  final List<Detection> detections;
  final double imageWidth;
  final double imageHeight;

  _DamageBboxOverlayPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final containerW = size.width;
    final containerH = size.height;

    // Match BoxFit.cover mapping (image is scaled to cover the container,
    // potentially cropping on either axis).
    final scale = math.max(containerW / imageWidth, containerH / imageHeight);
    final renderedW = imageWidth * scale;
    final renderedH = imageHeight * scale;

    final offsetX = (containerW - renderedW) / 2;
    final offsetY = (containerH - renderedH) / 2;

    for (final det in detections) {
      final color = AppTheme.getDamageColor(det.className);

      final left = offsetX + det.bbox.xMin * scale;
      final top = offsetY + det.bbox.yMin * scale;
      final right = offsetX + det.bbox.xMax * scale;
      final bottom = offsetY + det.bbox.yMax * scale;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.10);
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.90);

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DamageBboxOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}

class _NoDamageCard extends StatelessWidget {
  const _NoDamageCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF4F3FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green[600]),
            const SizedBox(width: 12),
            const Expanded(child: Text('No damage detected')),
          ],
        ),
      ),
    );
  }
}

class _DamagePartCard extends StatelessWidget {
  final Detection detection;
  final int index;

  const _DamagePartCard({
    required this.detection,
    required this.index,
  });

  String get _title {
    return detection.className
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getDamageColor(detection.className);
    final area = detection.areaPercentage;

    return Card(
      color: const Color(0xFFF4F3FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 74,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                AppTheme.getDamageIcon(detection.className),
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${(detection.confidence * 100).toStringAsFixed(0)}% confidence'
                    '${detection.severity != null ? ' - ${detection.severity}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (area != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Area affected: ${area.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisOverviewCard extends StatelessWidget {
  final DamageDetectionResponse detectionResult;
  final CostEstimationResponse? costResult;
  final ReportResponse? report;

  const _AnalysisOverviewCard({
    required this.detectionResult,
    required this.costResult,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final severity = report?.assessmentSummary.overallSeverity ??
        (detectionResult.numDetections == 0 ? 'none' : 'unknown');
    final severityColor = AppTheme.getSeverityColor(severity);
    final detections = detectionResult.detections;
    final confidenceDisplay = detections.isEmpty
        ? '—'
        : '${(detections.map((d) => d.confidence).reduce(math.max) * 100).toStringAsFixed(0)}%';

    return Card(
      color: const Color(0xFFF4F3FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Analysis report',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ReportStat(
                  icon: Icons.warning_amber_outlined,
                  label: 'Damages',
                  value: '${detectionResult.numDetections}',
                  color: detectionResult.numDetections > 0 ? Colors.orange : Colors.green,
                ),
                _ReportStat(
                  icon: Icons.verified_outlined,
                  label: 'Confidence',
                  value: confidenceDisplay,
                  color: Colors.blue,
                ),
                _ReportStat(
                  icon: Icons.attach_money,
                  label: 'Est. Cost',
                  value: costResult == null ? '-' : '\$${costResult!.totalCost.toStringAsFixed(0)}',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.shield_outlined, size: 16, color: severityColor),
                label: Text('Severity: ${severity.toUpperCase()}'),
                side: BorderSide(color: severityColor.withValues(alpha: 0.35)),
                backgroundColor: severityColor.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ReportStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CostSummaryCard extends StatelessWidget {
  final CostEstimationResponse cost;

  const _CostSummaryCard({required this.cost});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF4F3FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cost breakdown', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...cost.damages.map(
              (damage) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${damage.damageType.replaceAll('_', ' ')} (${damage.severity})',
                      ),
                    ),
                    Text('\$${damage.totalCost.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            _CostLine(label: 'Subtotal', value: '\$${cost.subtotal.toStringAsFixed(2)}'),
            _CostLine(
              label: 'GST (${(cost.taxRate * 100).toStringAsFixed(0)}%)',
              value: '\$${cost.taxAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '\$${cost.totalCost.toStringAsFixed(2)} ${cost.currency}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Estimate range: \$${cost.estimateRange['low']?.toStringAsFixed(2) ?? '-'} - '
              '\$${cost.estimateRange['high']?.toStringAsFixed(2) ?? '-'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CostLine extends StatelessWidget {
  final String label;
  final String value;

  const _CostLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  final AssessmentSummary summary;

  const _ReportSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(summary.summaryText),
            if (summary.primaryConcerns.isNotEmpty) ...[
              const SizedBox(height: 14),
              _BulletSection(
                title: 'Primary concerns',
                icon: Icons.priority_high_outlined,
                items: summary.primaryConcerns,
              ),
            ],
            if (summary.recommendedActions.isNotEmpty) ...[
              const SizedBox(height: 14),
              _BulletSection(
                title: 'Recommended actions',
                icon: Icons.checklist_outlined,
                items: summary.recommendedActions,
              ),
            ],
            if (summary.safetyNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _BulletSection(
                title: 'Safety notes',
                icon: Icons.health_and_safety_outlined,
                items: summary.safetyNotes,
                color: Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Color? color;

  const _BulletSection({
    required this.title,
    required this.icon,
    required this.items,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sectionColor = color ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: sectionColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: sectionColor,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: sectionColor)),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
