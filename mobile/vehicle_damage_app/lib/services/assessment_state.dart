/// State management for the assessment workflow

import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../models/damage_models.dart';

enum AssessmentStatus {
  idle,
  capturing,
  uploading,
  analyzing,
  estimatingCost,
  generatingReport,
  complete,
  error,
}

class AssessmentState extends ChangeNotifier {
  // Current status
  AssessmentStatus _status = AssessmentStatus.idle;
  AssessmentStatus get status => _status;
  
  // Image bytes (web-compatible)
  Uint8List? _imageBytes;
  Uint8List? get imageBytes => _imageBytes;
  Uint8List? _videoBytes;
  Uint8List? get videoBytes => _videoBytes;
  String? _imageName;
  String? get imageName => _imageName;
  String? _videoName;
  String? get videoName => _videoName;
  AssessmentMediaType _mediaType = AssessmentMediaType.image;
  AssessmentMediaType get mediaType => _mediaType;
  String _assessmentTitle = 'Untitled';
  String get assessmentTitle => _assessmentTitle;
  
  // Detection results
  DamageDetectionResponse? _detectionResult;
  DamageDetectionResponse? get detectionResult => _detectionResult;
  VideoDetectionResponse? _videoResult;
  VideoDetectionResponse? get videoResult => _videoResult;
  
  // Cost estimation
  CostEstimationResponse? _costEstimation;
  CostEstimationResponse? get costEstimation => _costEstimation;
  
  // Report
  ReportResponse? _report;
  ReportResponse? get report => _report;
  
  // Error message
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  // Progress message
  String _progressMessage = '';
  String get progressMessage => _progressMessage;
  
  /// Set the selected image bytes (web-compatible)
  void setImageBytes(Uint8List bytes, String name) {
    _imageBytes = bytes;
    _videoBytes = null;
    _imageName = name;
    _videoName = null;
    _mediaType = AssessmentMediaType.image;
    _assessmentTitle = 'Untitled';
    _status = AssessmentStatus.idle;
    _detectionResult = null;
    _videoResult = null;
    _costEstimation = null;
    _report = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Set the selected video bytes for the current app session only.
  void setVideoBytes(Uint8List bytes, String name) {
    _videoBytes = bytes;
    _imageBytes = null;
    _videoName = name;
    _imageName = null;
    _mediaType = AssessmentMediaType.video;
    _assessmentTitle = 'Untitled';
    _status = AssessmentStatus.idle;
    _detectionResult = null;
    _videoResult = null;
    _costEstimation = null;
    _report = null;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Clear current image and results
  void clear() {
    _imageBytes = null;
    _videoBytes = null;
    _imageName = null;
    _videoName = null;
    _mediaType = AssessmentMediaType.image;
    _assessmentTitle = 'Untitled';
    _detectionResult = null;
    _videoResult = null;
    _costEstimation = null;
    _report = null;
    _errorMessage = null;
    _status = AssessmentStatus.idle;
    _progressMessage = '';
    notifyListeners();
  }
  
  /// Update status
  void setStatus(AssessmentStatus status, {String? message}) {
    _status = status;
    _progressMessage = message ?? '';
    
    if (status == AssessmentStatus.error) {
      _errorMessage = message;
    }
    
    notifyListeners();
  }
  
  /// Set detection result
  void setDetectionResult(DamageDetectionResponse result) {
    _detectionResult = result;
    notifyListeners();
  }

  /// Set video detection result
  void setVideoResult(VideoDetectionResponse result) {
    _videoResult = result;
    notifyListeners();
  }
  
  /// Set cost estimation
  void setCostEstimation(CostEstimationResponse cost) {
    _costEstimation = cost;
    notifyListeners();
  }
  
  /// Set report
  void setReport(ReportResponse report) {
    _report = report;
    _status = AssessmentStatus.complete;
    notifyListeners();
  }

  void setAssessmentTitle(String title) {
    final trimmed = title.trim();
    _assessmentTitle = trimmed.isEmpty ? 'Untitled' : trimmed;
    notifyListeners();
  }
  
  /// Set error
  void setError(String message) {
    _errorMessage = message;
    _status = AssessmentStatus.error;
    notifyListeners();
  }
  
  /// Check if assessment is in progress
  bool get isProcessing => 
      _status == AssessmentStatus.uploading ||
      _status == AssessmentStatus.analyzing ||
      _status == AssessmentStatus.estimatingCost ||
      _status == AssessmentStatus.generatingReport;
  
  /// Check if we have results
  bool get hasResults => _detectionResult != null || _videoResult != null;
  
  /// Check if we have detected damages
  bool get hasDamages => 
      (_detectionResult != null && _detectionResult!.numDetections > 0) ||
      (_videoResult != null && _videoResult!.uniqueDetections > 0);
  
  /// Get damage count
  int get damageCount =>
      _detectionResult?.numDetections ?? _videoResult?.uniqueDetections ?? 0;
  
  /// Get total estimated cost
  double? get totalCost => _costEstimation?.totalCost;
  
  /// Get overall severity
  String? get overallSeverity => _report?.assessmentSummary.overallSeverity;
}
