/// Data models for the Vehicle Damage Assessment app

import 'dart:typed_data';

enum AssessmentMediaType {
  image,
  video,
}

AssessmentMediaType assessmentMediaTypeFromString(String? value) {
  switch (value) {
    case 'video':
      return AssessmentMediaType.video;
    case 'image':
    default:
      return AssessmentMediaType.image;
  }
}

String assessmentMediaTypeToString(AssessmentMediaType mediaType) {
  switch (mediaType) {
    case AssessmentMediaType.video:
      return 'video';
    case AssessmentMediaType.image:
      return 'image';
  }
}

/// Lightweight report history item persisted between app launches.
class AssessmentHistoryItem {
  final String id;
  final String title;
  final DateTime timestamp;
  final AssessmentMediaType mediaType;
  final int damageCount;
  final List<String> damageTypes;
  final double? totalCost;
  final String? severity;

  AssessmentHistoryItem({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.mediaType,
    required this.damageCount,
    required this.damageTypes,
    this.totalCost,
    this.severity,
  });

  factory AssessmentHistoryItem.fromJson(Map<String, dynamic> json) {
    return AssessmentHistoryItem(
      id: json['id'] as String,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Untitled',
      timestamp: DateTime.parse(json['timestamp'] as String),
      mediaType: assessmentMediaTypeFromString(json['media_type'] as String?),
      damageCount: json['damage_count'] as int,
      damageTypes: List<String>.from(json['damage_types'] as List? ?? const []),
      totalCost: json['total_cost'] != null
          ? (json['total_cost'] as num).toDouble()
          : null,
      severity: json['severity'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'timestamp': timestamp.toIso8601String(),
      'media_type': assessmentMediaTypeToString(mediaType),
      'damage_count': damageCount,
      'damage_types': damageTypes,
      'total_cost': totalCost,
      'severity': severity,
    };
  }
}

/// Session-only detail data. Media bytes are intentionally never serialized.
class SavedAssessmentSession {
  final AssessmentHistoryItem historyItem;
  final Uint8List? mediaBytes;
  final DamageDetectionResponse? detectionResult;
  final VideoDetectionResponse? videoResult;
  final CostEstimationResponse? costResult;
  final ReportResponse? report;

  SavedAssessmentSession({
    required this.historyItem,
    this.mediaBytes,
    this.detectionResult,
    this.videoResult,
    this.costResult,
    this.report,
  });
}

/// Bounding box for detected damage
class BoundingBox {
  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;

  BoundingBox({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  double get width => xMax - xMin;
  double get height => yMax - yMin;
  double get area => width * height;

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      xMin: (json['x_min'] as num).toDouble(),
      yMin: (json['y_min'] as num).toDouble(),
      xMax: (json['x_max'] as num).toDouble(),
      yMax: (json['y_max'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x_min': xMin,
      'y_min': yMin,
      'x_max': xMax,
      'y_max': yMax,
    };
  }
}

/// Single damage detection result
class Detection {
  final int classId;
  final String className;
  final double confidence;
  final BoundingBox bbox;
  final double? areaPercentage;
  final String? severity;

  Detection({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.bbox,
    this.areaPercentage,
    this.severity,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      classId: json['class_id'] as int,
      className: json['class_name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      bbox: BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>),
      areaPercentage: json['area_percentage'] != null
          ? (json['area_percentage'] as num).toDouble()
          : null,
      severity: json['severity'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'class_name': className,
      'confidence': confidence,
      'bbox': bbox.toJson(),
      'area_percentage': areaPercentage,
      'severity': severity,
    };
  }
}

/// Response from damage detection endpoint
class DamageDetectionResponse {
  final bool success;
  final String message;
  final List<Detection> detections;
  final int numDetections;
  final String? annotatedImage;
  final double inferenceTimeMs;
  final Map<String, int>? imageSize;

  DamageDetectionResponse({
    required this.success,
    required this.message,
    required this.detections,
    required this.numDetections,
    this.annotatedImage,
    required this.inferenceTimeMs,
    this.imageSize,
  });

  factory DamageDetectionResponse.fromJson(Map<String, dynamic> json) {
    return DamageDetectionResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      detections: (json['detections'] as List<dynamic>)
          .map((e) => Detection.fromJson(e as Map<String, dynamic>))
          .toList(),
      numDetections: json['num_detections'] as int,
      annotatedImage: json['annotated_image'] as String?,
      inferenceTimeMs: (json['inference_time_ms'] as num).toDouble(),
      imageSize: json['image_size'] != null
          ? Map<String, int>.from(json['image_size'] as Map)
          : null,
    );
  }
}

/// Cost breakdown for a single damage
class DamageCostItem {
  final String damageType;
  final String severity;
  final double baseCost;
  final double severityMultiplier;
  final double laborHours;
  final double laborCost;
  final double partsCost;
  final double totalCost;

  DamageCostItem({
    required this.damageType,
    required this.severity,
    required this.baseCost,
    required this.severityMultiplier,
    required this.laborHours,
    required this.laborCost,
    required this.partsCost,
    required this.totalCost,
  });

  factory DamageCostItem.fromJson(Map<String, dynamic> json) {
    return DamageCostItem(
      damageType: json['damage_type'] as String,
      severity: json['severity'] as String,
      baseCost: (json['base_cost'] as num).toDouble(),
      severityMultiplier: (json['severity_multiplier'] as num).toDouble(),
      laborHours: (json['labor_hours'] as num).toDouble(),
      laborCost: (json['labor_cost'] as num).toDouble(),
      partsCost: (json['parts_cost'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
    );
  }
}

/// Response from cost estimation endpoint
class CostEstimationResponse {
  final bool success;
  final String message;
  final List<DamageCostItem> damages;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double totalCost;
  final String currency;
  final Map<String, double> estimateRange;

  CostEstimationResponse({
    required this.success,
    required this.message,
    required this.damages,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.totalCost,
    required this.currency,
    required this.estimateRange,
  });

  factory CostEstimationResponse.fromJson(Map<String, dynamic> json) {
    return CostEstimationResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      damages: (json['damages'] as List<dynamic>)
          .map((e) => DamageCostItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxRate: (json['tax_rate'] as num).toDouble(),
      taxAmount: (json['tax_amount'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      currency: json['currency'] as String,
      estimateRange: Map<String, double>.from(
        (json['estimate_range'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ),
    );
  }
}

/// Assessment summary from report generation
class AssessmentSummary {
  final String overallSeverity;
  final List<String> primaryConcerns;
  final List<String> recommendedActions;
  final List<String> safetyNotes;
  final String summaryText;

  AssessmentSummary({
    required this.overallSeverity,
    required this.primaryConcerns,
    required this.recommendedActions,
    required this.safetyNotes,
    required this.summaryText,
  });

  factory AssessmentSummary.fromJson(Map<String, dynamic> json) {
    return AssessmentSummary(
      overallSeverity: json['overall_severity'] as String,
      primaryConcerns: List<String>.from(json['primary_concerns'] as List),
      recommendedActions: List<String>.from(json['recommended_actions'] as List),
      safetyNotes: List<String>.from(json['safety_notes'] as List),
      summaryText: json['summary_text'] as String,
    );
  }
}

/// Response from report generation endpoint
class ReportResponse {
  final bool success;
  final String message;
  final String reportId;
  final DateTime generatedAt;
  final AssessmentSummary assessmentSummary;
  final int damageCount;
  final double? totalCost;
  final Map<String, dynamic>? reportData;

  ReportResponse({
    required this.success,
    required this.message,
    required this.reportId,
    required this.generatedAt,
    required this.assessmentSummary,
    required this.damageCount,
    this.totalCost,
    this.reportData,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['generated_at'] as String);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    AssessmentSummary parsedSummary;
    try {
      parsedSummary = AssessmentSummary.fromJson(
        json['assessment_summary'] as Map<String, dynamic>,
      );
    } catch (_) {
      parsedSummary = AssessmentSummary(
        overallSeverity: 'unknown',
        primaryConcerns: [],
        recommendedActions: [],
        safetyNotes: [],
        summaryText: 'Assessment complete.',
      );
    }

    return ReportResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String? ?? '',
      reportId: json['report_id'] as String? ?? '',
      generatedAt: parsedDate,
      assessmentSummary: parsedSummary,
      damageCount: json['damage_count'] as int? ?? 0,
      totalCost: json['total_cost'] != null
          ? (json['total_cost'] as num).toDouble()
          : null,
      reportData: json['report_data'] as Map<String, dynamic>?,
    );
  }
}

/// Frame result from video processing
class VideoFrameResult {
  final int frameNumber;
  final double timestampSec;
  final List<Detection> detections;
  final String? annotatedFrame;

  VideoFrameResult({
    required this.frameNumber,
    required this.timestampSec,
    required this.detections,
    this.annotatedFrame,
  });

  factory VideoFrameResult.fromJson(Map<String, dynamic> json) {
    return VideoFrameResult(
      frameNumber: json['frame_number'] as int,
      timestampSec: (json['timestamp_sec'] as num).toDouble(),
      detections: (json['detections'] as List<dynamic>)
          .map((e) => Detection.fromJson(e as Map<String, dynamic>))
          .toList(),
      annotatedFrame: json['annotated_frame'] as String?,
    );
  }
}

/// Response from video damage detection endpoint
class VideoDetectionResponse {
  final bool success;
  final String message;
  final Map<String, dynamic> videoInfo;
  final List<Detection> aggregatedDetections;
  final List<VideoFrameResult> frameResults;
  final int totalDetections;
  final int uniqueDetections;
  final double totalInferenceTimeMs;

  VideoDetectionResponse({
    required this.success,
    required this.message,
    required this.videoInfo,
    required this.aggregatedDetections,
    required this.frameResults,
    required this.totalDetections,
    required this.uniqueDetections,
    required this.totalInferenceTimeMs,
  });

  factory VideoDetectionResponse.fromJson(Map<String, dynamic> json) {
    return VideoDetectionResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      videoInfo: Map<String, dynamic>.from(json['video_info'] as Map),
      aggregatedDetections: (json['aggregated_detections'] as List<dynamic>)
          .map((e) => Detection.fromJson(e as Map<String, dynamic>))
          .toList(),
      frameResults: (json['frame_results'] as List<dynamic>)
          .map((e) => VideoFrameResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDetections: json['total_detections'] as int,
      uniqueDetections: json['unique_detections'] as int,
      totalInferenceTimeMs: (json['total_inference_time_ms'] as num).toDouble(),
    );
  }
  
  /// Get duration in seconds
  double get durationSec => (videoInfo['duration_sec'] as num?)?.toDouble() ?? 0;
  
  /// Get frames per second
  double get fps => (videoInfo['fps'] as num?)?.toDouble() ?? 0;
  
  /// Get total frames in video
  int get totalFrames => (videoInfo['total_frames'] as int?) ?? 0;
  
  /// Get number of frames analyzed
  int get framesAnalyzed => (videoInfo['frames_analyzed'] as int?) ?? 0;
}

/// Chat response from AI Assistant
class ChatResponse {
  final bool success;
  final String response;
  final String assessmentId;

  ChatResponse({
    required this.success,
    required this.response,
    required this.assessmentId,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      success: json['success'] as bool? ?? false,
      response: json['response'] as String? ?? 'No response',
      assessmentId: json['assessment_id'] as String? ?? '',
    );
  }
}
