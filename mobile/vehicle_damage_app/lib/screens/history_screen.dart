/// History Screen - View past assessments

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/damage_models.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AssessmentHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('assessment_history') ?? [];
    
    setState(() {
      _history = historyJson
          .map((json) => AssessmentHistoryItem.fromJson(jsonDecode(json)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all assessment history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('assessment_history');
      setState(() {
        _history = [];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared')),
        );
      }
    }
  }

  Future<void> _deleteItem(AssessmentHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('assessment_history') ?? [];
    
    historyJson.removeWhere((json) {
      final parsed = AssessmentHistoryItem.fromJson(jsonDecode(json));
      return parsed.id == item.id;
    });
    
    await prefs.setStringList('assessment_history', historyJson);
    
    setState(() {
      _history.removeWhere((h) => h.id == item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Car Damage Analyzer'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearHistory,
              tooltip: 'Clear History',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Text(
                      'Co-ders Intl',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_history.isEmpty)
                    _EmptyState()
                  else
                    ..._history.map((item) {
                      return _HistoryCard(
                        item: item,
                        onDelete: () => _deleteItem(item),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
              title: Text(item.title),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                  Text('Date: ${DateFormat('dd MMM yyyy – HH:mm').format(item.timestamp)}'),
                  const SizedBox(height: 8),
                  Text('Media: ${item.mediaType == AssessmentMediaType.video ? 'Video' : 'Image'}'),
                                  const SizedBox(height: 8),
                                  if (item.severity != null)
                                    Text('Severity: ${item.severity!.toUpperCase()}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  if (item.damageTypes.isNotEmpty) ...[
                                    const Text('Damage types:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    ...item.damageTypes.map((t) => Text('  • ${t.replaceAll("_", " ")}'))
                                  ],
                                  if (item.totalCost != null) ...[
                                    const SizedBox(height: 8),
                                    Text('Est. Cost: \$${item.totalCost!.toStringAsFixed(2)} AUD',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        },
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Assessment History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your past assessments will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.item,
    required this.onDelete,
    required this.onTap,
  });

  String get _formattedDate {
    final now = DateTime.now();
    final diff = now.difference(item.timestamp);
    
    if (diff.inDays == 0) {
      return 'Today, ${DateFormat.jm().format(item.timestamp)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday, ${DateFormat.jm().format(item.timestamp)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat.yMMMd().format(item.timestamp);
    }
  }

  Color get _severityColor {
    switch (item.severity?.toLowerCase()) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'minor':
        return Colors.yellow[700]!;
      case 'none':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 92,
                height: 68,
                decoration: BoxDecoration(
                  color: _severityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _severityColor.withOpacity(0.22)),
                ),
                child: Icon(
                  item.mediaType == AssessmentMediaType.video
                      ? Icons.videocam
                      : Icons.directions_car,
                  color: _severityColor,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _severityColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.severity?.toUpperCase() ?? 'N/A',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _severityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.damageCount} damage${item.damageCount != 1 ? 's' : ''} detected',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.damageTypes.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: item.damageTypes.take(3).map((type) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              type.replaceAll('_', ' '),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    if (item.totalCost != null)
                      Text(
                        'Est. Cost: \$${item.totalCost!.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_right_rounded),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.grey[400], size: 20),
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
