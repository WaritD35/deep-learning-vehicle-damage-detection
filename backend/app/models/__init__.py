"""
Damage Detection Model Service.
Handles model loading and inference for vehicle damage detection.
"""

import os
import time
import base64
from io import BytesIO
from pathlib import Path
from typing import List, Tuple, Optional, Union

import numpy as np
from PIL import Image

# Lazy imports for heavy dependencies
torch = None
cv2 = None

def _ensure_imports():
    """Lazily import heavy dependencies."""
    global torch, cv2
    if torch is None:
        import torch as _torch
        torch = _torch
    if cv2 is None:
        import cv2 as _cv2
        cv2 = _cv2

from ..config import settings, get_device
from ..schemas import Detection, BoundingBox


class DamageDetector:
    """
    Vehicle damage detection service using trained deep learning models.
    Supports YOLO, Faster R-CNN, and RT-DETR architectures.
    """
    
    def __init__(self, model_path: Optional[str] = None, model_type: Optional[str] = None):
        """
        Initialize the damage detector.
        
        Args:
            model_path: Path to the trained model weights
            model_type: Type of model ('yolo', 'yolov8', 'yolo11', 'faster_rcnn', 'rtdetr')
        """
        self.model_path = model_path or settings.MODEL_PATH
        self.model_type = model_type or settings.MODEL_TYPE
        self.device = get_device()
        self.model = None
        self.class_names = settings.CLASS_NAMES
        self.conf_threshold = settings.CONF_THRESHOLD
        self.iou_threshold = settings.IOU_THRESHOLD
        self.image_size = settings.IMAGE_SIZE
        
        self._load_model()
    
    def _load_model(self):
        """Load the detection model based on model type."""
        _ensure_imports()
        
        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"Model not found at: {self.model_path}")
        
        print(f"Loading model from: {self.model_path}")
        print(f"Model type: {self.model_type}")
        print(f"Device: {self.device}")
        
        if self.model_type.lower() in ['yolo', 'yolov8', 'yolov8m', 'yolo11', 'yolo11m']:
            self._load_yolo_model()
        elif self.model_type.lower() == 'rtdetr':
            self._load_rtdetr_model()
        elif self.model_type.lower() == 'faster_rcnn':
            self._load_faster_rcnn_model()
        else:
            # Try to auto-detect based on file
            self._load_yolo_model()
        
        print("✓ Model loaded successfully!")
    
    def _load_yolo_model(self):
        """Load YOLO model using ultralytics."""
        from ultralytics import YOLO
        self.model = YOLO(self.model_path)
        self.model.to(self.device)
    
    def _load_rtdetr_model(self):
        """Load RT-DETR model using ultralytics."""
        from ultralytics import RTDETR
        self.model = RTDETR(self.model_path)
        self.model.to(self.device)
    
    def _load_faster_rcnn_model(self):
        """Load Faster R-CNN model."""
        from torchvision.models.detection import fasterrcnn_resnet50_fpn_v2
        from torchvision.models.detection.faster_rcnn import FastRCNNPredictor
        
        # Create model architecture
        model = fasterrcnn_resnet50_fpn_v2(weights=None)
        in_features = model.roi_heads.box_predictor.cls_score.in_features
        model.roi_heads.box_predictor = FastRCNNPredictor(in_features, len(self.class_names) + 1)
        
        # Load weights
        checkpoint = torch.load(self.model_path, map_location=self.device)
        model.load_state_dict(checkpoint['model_state_dict'])
        
        model = model.to(self.device)
        model.eval()
        self.model = model
    
    def predict(
        self, 
        image: Union[str, np.ndarray, Image.Image],
        conf_threshold: Optional[float] = None,
        return_annotated: bool = True
    ) -> Tuple[List[Detection], Optional[np.ndarray], float]:
        """
        Run damage detection on an image.
        
        Args:
            image: Image as file path, numpy array, or PIL Image
            conf_threshold: Confidence threshold (uses default if None)
            return_annotated: Whether to return annotated image
            
        Returns:
            Tuple of (detections, annotated_image, inference_time_ms)
        """
        conf = conf_threshold or self.conf_threshold
        
        # Load and preprocess image
        img_array, original_size = self._preprocess_image(image)
        original_rgb = img_array.copy()
        
        # Run inference
        start_time = time.time()
        
        if self.model_type.lower() in ['yolo', 'yolov8', 'yolov8m', 'yolo11', 'yolo11m', 'rtdetr']:
            detections, _ = self._predict_yolo(img_array, conf)
        else:
            detections, _ = self._predict_faster_rcnn(img_array, conf)
        
        inference_time = (time.time() - start_time) * 1000
        
        # Calculate area percentages and severity
        total_area = original_size[0] * original_size[1]
        for det in detections:
            area_pct = (det.bbox.area / total_area) * 100
            det.area_percentage = round(area_pct, 2)
            det.severity = self._calculate_severity(area_pct)
        
        annotated = None
        if return_annotated and len(detections) > 0:
            # Keep a pristine RGB copy for annotation (inference may touch img_array).
            annotated = self._annotate_image(
                original_rgb, detections, inference_time
            )
        
        return detections, annotated, inference_time
    
    def _preprocess_image(self, image: Union[str, bytes, np.ndarray, Image.Image]) -> Tuple[np.ndarray, Tuple[int, int]]:
        """Preprocess image for inference."""
        _ensure_imports()
        
        if isinstance(image, bytes):
            # Handle raw bytes from file upload
            img = Image.open(BytesIO(image)).convert('RGB')
        elif isinstance(image, str):
            if os.path.exists(image):
                img = Image.open(image).convert('RGB')
            elif image.startswith('data:image'):
                # Handle data URL
                image_data = image.split(',')[1]
                img = Image.open(BytesIO(base64.b64decode(image_data))).convert('RGB')
            else:
                # Assume base64
                img = Image.open(BytesIO(base64.b64decode(image))).convert('RGB')
        elif isinstance(image, np.ndarray):
            # Check if it's BGR (from cv2) or RGB
            if len(image.shape) == 3 and image.shape[2] == 3:
                img = Image.fromarray(image)
            else:
                img = Image.fromarray(image).convert('RGB')
        elif isinstance(image, Image.Image):
            img = image.convert('RGB')
        else:
            # Try to open as bytes-like object
            img = Image.open(BytesIO(image)).convert('RGB')
        
        original_size = img.size  # (width, height)
        img_array = np.array(img)
        
        return img_array, original_size
    
    def _predict_yolo(
        self,
        img_array: np.ndarray,
        conf: float,
    ) -> Tuple[List[Detection], Optional[np.ndarray]]:
        """Run YOLO/RT-DETR inference."""
        results = self.model.predict(
            img_array,
            conf=conf,
            iou=self.iou_threshold,
            imgsz=self.image_size,
            verbose=False
        )
        
        detections = []
        for result in results:
            boxes = result.boxes
            for i, box in enumerate(boxes):
                xyxy = box.xyxy[0].cpu().numpy()
                conf_score = float(box.conf[0].cpu().numpy())
                class_id = int(box.cls[0].cpu().numpy())
                
                detection = Detection(
                    class_id=class_id,
                    class_name=self.class_names[class_id],
                    confidence=round(conf_score, 4),
                    bbox=BoundingBox(
                        x_min=float(xyxy[0]),
                        y_min=float(xyxy[1]),
                        x_max=float(xyxy[2]),
                        y_max=float(xyxy[3])
                    )
                )
                detections.append(detection)
        
        return detections, None
    
    def _predict_faster_rcnn(
        self,
        img_array: np.ndarray,
        conf: float,
    ) -> Tuple[List[Detection], Optional[np.ndarray]]:
        """Run Faster R-CNN inference."""
        _ensure_imports()
        from torchvision import transforms
        
        # Prepare input
        transform = transforms.ToTensor()
        img_tensor = transform(img_array).unsqueeze(0).to(self.device)
        
        # Inference
        self.model.eval()
        with torch.no_grad():
            outputs = self.model(img_tensor)[0]
        
        # Process detections
        detections = []
        boxes = outputs['boxes'].cpu().numpy()
        scores = outputs['scores'].cpu().numpy()
        labels = outputs['labels'].cpu().numpy()
        
        for i, (box, score, label) in enumerate(zip(boxes, scores, labels)):
            if score >= conf:
                class_id = label - 1  # Convert back to 0-indexed
                if 0 <= class_id < len(self.class_names):
                    detection = Detection(
                        class_id=class_id,
                        class_name=self.class_names[class_id],
                        confidence=round(float(score), 4),
                        bbox=BoundingBox(
                            x_min=float(box[0]),
                            y_min=float(box[1]),
                            x_max=float(box[2]),
                            y_max=float(box[3])
                        )
                    )
                    detections.append(detection)
        
        return detections, None
    
    def _annotate_image(
        self,
        image: np.ndarray,
        detections: List[Detection],
        inference_time_ms: float,
    ) -> np.ndarray:
        """Annotate an RGB image with detection boxes; returns RGB."""
        _ensure_imports()
        # OpenCV drawing uses BGR; the rest of the pipeline uses RGB.
        bgr = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
        colors = {
            'dent': (0, 0, 255),            # Red (BGR)
            'scratch': (0, 255, 0),         # Green
            'crack': (255, 0, 0),           # Blue
            'glass_shatter': (0, 255, 255), # Yellow
            'lamp_broken': (255, 0, 255),   # Magenta
            'tire_flat': (255, 255, 0),     # Cyan
        }
        
        for det in detections:
            x1 = int(det.bbox.x_min)
            y1 = int(det.bbox.y_min)
            x2 = int(det.bbox.x_max)
            y2 = int(det.bbox.y_max)
            
            color = colors.get(det.class_name, (0, 255, 0))
            
            cv2.rectangle(bgr, (x1, y1), (x2, y2), color, 2)
            
            t = round(inference_time_ms)
            label = f'{det.class_name} {t}ms'
            (label_w, label_h), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
            cv2.rectangle(bgr, (x1, y1 - label_h - 10), (x1 + label_w, y1), color, -1)
            cv2.putText(bgr, label, (x1, y1 - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        
        return cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    
    def _calculate_severity(self, area_percentage: float) -> str:
        """Calculate damage severity based on area percentage."""
        if area_percentage < 5:
            return "small"
        elif area_percentage < 15:
            return "medium"
        else:
            return "large"
    
    @staticmethod
    def image_to_base64(image: np.ndarray) -> str:
        """Convert numpy image to base64 string."""
        pil_image = Image.fromarray(image)
        buffer = BytesIO()
        pil_image.save(buffer, format='JPEG', quality=90)
        return base64.b64encode(buffer.getvalue()).decode('utf-8')
    
    @staticmethod
    def base64_to_image(base64_str: str) -> np.ndarray:
        """Convert base64 string to numpy image."""
        if base64_str.startswith('data:image'):
            base64_str = base64_str.split(',')[1]
        image_data = base64.b64decode(base64_str)
        image = Image.open(BytesIO(image_data)).convert('RGB')
        return np.array(image)


# Global detector instance (lazy loading)
_detector: Optional[DamageDetector] = None


def get_detector() -> DamageDetector:
    """Get or create the global detector instance."""
    global _detector
    if _detector is None:
        _detector = DamageDetector()
    return _detector


def load_detector(model_path: str, model_type: str) -> DamageDetector:
    """Load a new detector with specific model."""
    global _detector
    _detector = DamageDetector(model_path=model_path, model_type=model_type)
    return _detector
