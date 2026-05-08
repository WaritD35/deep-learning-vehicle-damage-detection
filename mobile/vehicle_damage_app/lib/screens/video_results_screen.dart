// Video Results Screen - Display video analysis results

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/damage_models.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class VideoResultsScreen extends StatefulWidget {
  final VideoDetectionResponse videoResult;
  final CostEstimationResponse costResult;
  final ReportResponse? reportResult;
  final Uint8List? videoBytes;
  final String initialTitle;
  final bool readOnly;

  const VideoResultsScreen({
    super.key,
    required this.videoResult,
    required this.costResult,
    this.reportResult,
    this.videoBytes,
    this.initialTitle = 'Untitled',
    this.readOnly = false,
  });

  @override
  State<VideoResultsScreen> createState() => _VideoResultsScreenState();
}

class _VideoResultsScreenState extends State<VideoResultsScreen> {
  int _selectedFrameIndex = 0;
  late final TextEditingController _titleController;
  bool _isSaving = false;

  Uint8List? _videoThumbnailBytes() {
    final firstDamagedFrame = widget.videoResult.frameResults
        .where(
          (frame) =>
              frame.detections.isNotEmpty &&
              frame.annotatedFrame != null &&
              frame.annotatedFrame!.isNotEmpty,
        )
        .cast<VideoFrameResult?>()
        .firstWhere(
          (frame) => frame != null,
          orElse: () => null,
        );

    final firstFrameFallback = widget.videoResult.frameResults
        .where((frame) => frame.annotatedFrame != null && frame.annotatedFrame!.isNotEmpty)
        .cast<VideoFrameResult?>()
        .firstWhere(
          (frame) => frame != null,
          orElse: () => null,
        );

    final thumbnailBase64 =
        firstDamagedFrame?.annotatedFrame ?? firstFrameFallback?.annotatedFrame;
    if (thumbnailBase64 != null && thumbnailBase64.isNotEmpty) {
      try {
        return base64Decode(thumbnailBase64);
      } catch (_) {
        // Keep fallback behavior when frame payload is malformed.
      }
    }
    return widget.videoBytes;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveVideoAssessment() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final title = _titleController.text.trim().isEmpty
        ? 'Untitled'
        : _titleController.text.trim();
    final historyItem = AssessmentHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      timestamp: DateTime.now(),
      mediaType: AssessmentMediaType.video,
      damageCount: widget.videoResult.uniqueDetections,
      damageTypes: widget.videoResult.aggregatedDetections
          .map((d) => d.className)
          .toSet()
          .toList(),
      totalCost: widget.costResult.totalCost,
      severity: widget.reportResult?.assessmentSummary.overallSeverity,
    );

    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('assessment_history') ?? [];
    historyJson.insert(0, jsonEncode(historyItem.toJson()));
    if (historyJson.length > 50) {
      historyJson.removeRange(50, historyJson.length);
    }
    await prefs.setStringList('assessment_history', historyJson);

    if (!mounted) return;
    Navigator.of(context).pop(
      SavedAssessmentSession(
        historyItem: historyItem,
        mediaBytes: _videoThumbnailBytes(),
        videoResult: widget.videoResult,
        costResult: widget.costResult,
        report: widget.reportResult,
      ),
    );
  }

  void _openFrameGallery(int initialIndex) {
    final frames = widget.videoResult.frameResults;
    if (frames.isEmpty) return;
    final safeInitialIndex = initialIndex.clamp(0, frames.length - 1);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (_) {
        final pageController = PageController(initialPage: safeInitialIndex);
        var currentPage = safeInitialIndex;
        return GestureDetector(
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
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Frame ${frames[currentPage].frameNumber} - '
                                '${frames[currentPage].timestampSec.toStringAsFixed(1)}s',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                          child: PageView.builder(
                            controller: pageController,
                            itemCount: frames.length,
                            onPageChanged: (value) {
                              currentPage = value;
                              setModalState(() {});
                            },
                            itemBuilder: (context, index) {
                              final frame = frames[index];
                              if (frame.annotatedFrame == null ||
                                  frame.annotatedFrame!.isEmpty) {
                                return Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F3FB),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Text('No frame image available'),
                                  ),
                                );
                              }
                              return Center(
                                child: Image.memory(
                                  base64Decode(frame.annotatedFrame!),
                                  fit: BoxFit.contain,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.videoResult;
    final cost = widget.costResult;
    final report = widget.reportResult;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : AppTheme.backgroundColor,
      body: SafeArea(
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
                      'Video Analysis',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F3FB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _titleController,
                            readOnly: widget.readOnly,
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
                        if (result.frameResults.isNotEmpty) ...[
                          Text(
                            'Key Frames with Detections',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _KeyFramesSection(
                            frameResults: result.frameResults,
                            selectedIndex: _selectedFrameIndex,
                            onFrameSelected: (index) {
                              setState(() => _selectedFrameIndex = index);
                            },
                            onOpenGallery: _openFrameGallery,
                          ),
                          const SizedBox(height: 18),
                        ],
                        _SummaryCard(result: result, cost: cost, report: report),
                        const SizedBox(height: 18),
                        Text(
                          'Video damages',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        if (result.aggregatedDetections.isEmpty)
                          const _NoDamageCard()
                        else
                          ...result.aggregatedDetections.asMap().entries.map(
                                (entry) => _VideoDamagePartCard(
                                  detection: entry.value,
                                  index: entry.key + 1,
                                ),
                              ),
                        if (!widget.readOnly) ...[
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveVideoAssessment,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _CostBreakdownCard(cost: cost),
                        const SizedBox(height: 16),
                        _VideoInfoCard(result: result),
                        if (report != null) ...[
                          const SizedBox(height: 16),
                          _VideoReportSummaryCard(summary: report.assessmentSummary),
                        ],
                        const SizedBox(height: 24),
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

class _SummaryCard extends StatelessWidget {
  final VideoDetectionResponse result;
  final CostEstimationResponse cost;
  final ReportResponse? report;

  const _SummaryCard({
    required this.result,
    required this.cost,
    this.report,
  });

  @override
  Widget build(BuildContext context) {
    final severity = report?.assessmentSummary.overallSeverity ??
        (result.uniqueDetections == 0 ? 'none' : 'unknown');
    final severityColor = AppTheme.getSeverityColor(severity);
    final detections = result.aggregatedDetections;
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
                Icon(Icons.fact_check_outlined,
                    color: Theme.of(context).colorScheme.primary),
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
                  value: '${result.uniqueDetections}',
                  color: result.uniqueDetections > 0 ? Colors.orange : Colors.green,
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
                  value: '\$${cost.totalCost.toStringAsFixed(0)}',
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

class _VideoInfoCard extends StatelessWidget {
  final VideoDetectionResponse result;

  const _VideoInfoCard({required this.result});

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
            Row(
              children: [
                Icon(Icons.movie_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Video information',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Duration', value: '${result.durationSec.toStringAsFixed(1)}s'),
            _InfoRow(label: 'FPS', value: result.fps.toStringAsFixed(1)),
            _InfoRow(label: 'Total Frames', value: '${result.totalFrames}'),
            _InfoRow(label: 'Frames Analyzed', value: '${result.framesAnalyzed}'),
            _InfoRow(
              label: 'Processing Time',
              value: '${(result.totalInferenceTimeMs / 1000).toStringAsFixed(2)}s',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
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

class _VideoDamagePartCard extends StatelessWidget {
  final Detection detection;
  final int index;

  const _VideoDamagePartCard({required this.detection, required this.index});

  String get _title {
    return detection.className
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
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
              child: Icon(AppTheme.getDamageIcon(detection.className),
                  color: color, size: 28),
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

class _CostBreakdownCard extends StatelessWidget {
  final CostEstimationResponse cost;

  const _CostBreakdownCard({required this.cost});

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
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${d.damageType.replaceAll('_', ' ')} (${d.severity})',
                      ),
                    ),
                    Text('\$${d.totalCost.toStringAsFixed(2)}'),
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
                  child: Text('Total',
                      style: Theme.of(context).textTheme.titleMedium),
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

  const _CostLine({required this.label, required this.value});

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

class _VideoReportSummaryCard extends StatelessWidget {
  final AssessmentSummary summary;

  const _VideoReportSummaryCard({required this.summary});

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
            Text('Report summary', style: Theme.of(context).textTheme.titleMedium),
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

class _HeaderIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
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
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _KeyFramesSection extends StatelessWidget {
  final List<VideoFrameResult> frameResults;
  final int selectedIndex;
  final Function(int) onFrameSelected;
  final Function(int) onOpenGallery;

  const _KeyFramesSection({
    required this.frameResults,
    required this.selectedIndex,
    required this.onFrameSelected,
    required this.onOpenGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thumbnail strip
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: frameResults.length,
            itemBuilder: (context, index) {
              final frame = frameResults[index];
              final isSelected = index == selectedIndex;
              
              return GestureDetector(
                onTap: () {
                  onFrameSelected(index);
                  onOpenGallery(index);
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300]!,
                      width: isSelected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (frame.annotatedFrame != null)
                          Image.memory(
                            base64Decode(frame.annotatedFrame!),
                            fit: BoxFit.cover,
                          )
                        else
                          Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${frame.timestampSec.toStringAsFixed(1)}s',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Selected frame preview — same card style as photo PreviewCard
        if (frameResults.isNotEmpty && selectedIndex < frameResults.length)
          _FramePreviewCard(
            frame: frameResults[selectedIndex],
            onTap: () => onOpenGallery(selectedIndex),
          ),
      ],
    );
  }
}

class _FramePreviewCard extends StatelessWidget {
  final VideoFrameResult frame;
  final VoidCallback? onTap;

  const _FramePreviewCard({required this.frame, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = frame.annotatedFrame != null;

    return Card(
      color: const Color(0xFFF4F3FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: hasImage ? onTap : null,
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasImage
                  ? Image.memory(
                      base64Decode(frame.annotatedFrame!),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.movie_outlined, size: 56),
                    ),
              // Frame info badge (bottom-left)
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Frame ${frame.frameNumber} · ${frame.timestampSec.toStringAsFixed(1)}s'
                    ' · ${frame.detections.length} damage${frame.detections.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
              // Tap-to-view badge (bottom-right) — matches photo screen
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
