"""
Utility functions for image preprocessing and visualization.
"""

import base64
from io import BytesIO
from typing import Tuple, Optional
import numpy as np
from PIL import Image

# Lazy import for cv2
_cv2 = None

def _get_cv2():
    global _cv2
    if _cv2 is None:
        import cv2
        _cv2 = cv2
    return _cv2


def load_image(source) -> Tuple[np.ndarray, Tuple[int, int]]:
    """
    Load image from various sources.
    
    Args:
        source: File path, base64 string, bytes, or PIL Image
        
    Returns:
        Tuple of (numpy array in RGB, original size as (width, height))
    """
    if isinstance(source, str):
        if source.startswith('data:image'):
            # Data URL
            image_data = source.split(',')[1]
            img = Image.open(BytesIO(base64.b64decode(image_data)))
        elif source.startswith('/') or source.startswith('.') or (len(source) < 260 and ('/' in source or '\\' in source) and '.' in source.split('/')[-1]):
            # File path — must start with / or . or look like a real path with extension
            img = Image.open(source)
        else:
            # Assume base64
            img = Image.open(BytesIO(base64.b64decode(source)))
    elif isinstance(source, bytes):
        img = Image.open(BytesIO(source))
    elif isinstance(source, np.ndarray):
        if source.shape[-1] == 3:
            # Assume BGR, convert to RGB
            cv2 = _get_cv2()
            img = Image.fromarray(cv2.cvtColor(source, cv2.COLOR_BGR2RGB))
        else:
            img = Image.fromarray(source)
    else:
        img = source
    
    img = img.convert('RGB')
    return np.array(img), img.size


def resize_image(
    image: np.ndarray, 
    target_size: int = 640,
    keep_aspect: bool = True
) -> Tuple[np.ndarray, float]:
    """
    Resize image to target size.
    
    Args:
        image: Input image as numpy array
        target_size: Target size (width or height)
        keep_aspect: Whether to maintain aspect ratio
        
    Returns:
        Tuple of (resized image, scale factor)
    """
    h, w = image.shape[:2]
    
    if keep_aspect:
        scale = target_size / max(h, w)
        new_w = int(w * scale)
        new_h = int(h * scale)
    else:
        new_w = new_h = target_size
        scale = target_size / max(h, w)
    
    cv2 = _get_cv2()
    resized = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
    return resized, scale


def image_to_base64(image: np.ndarray, format: str = 'JPEG', quality: int = 90) -> str:
    """
    Convert numpy image to base64 string.
    
    Args:
        image: Image as numpy array (RGB)
        format: Output format (JPEG, PNG)
        quality: JPEG quality (1-100)
        
    Returns:
        Base64 encoded string
    """
    pil_image = Image.fromarray(image)
    buffer = BytesIO()
    
    if format.upper() == 'JPEG':
        pil_image.save(buffer, format='JPEG', quality=quality)
    else:
        pil_image.save(buffer, format=format)
    
    return base64.b64encode(buffer.getvalue()).decode('utf-8')


def base64_to_image(base64_str: str) -> np.ndarray:
    """
    Convert base64 string to numpy image.
    
    Args:
        base64_str: Base64 encoded image string
        
    Returns:
        Image as numpy array (RGB)
    """
    if base64_str.startswith('data:image'):
        base64_str = base64_str.split(',')[1]
    
    image_data = base64.b64decode(base64_str)
    image = Image.open(BytesIO(image_data)).convert('RGB')
    return np.array(image)


def draw_detections(
    image: np.ndarray,
    detections: list,
    colors: Optional[dict] = None,
    thickness: int = 2,
    font_scale: float = 0.5
) -> np.ndarray:
    """
    Draw detection boxes on image.
    
    Args:
        image: Input image as numpy array
        detections: List of Detection objects
        colors: Optional color mapping for classes
        thickness: Line thickness
        font_scale: Font scale for labels
        
    Returns:
        Annotated image
    """
    if colors is None:
        colors = {
            'dent': (0, 0, 255),
            'scratch': (0, 255, 0),
            'crack': (255, 0, 0),
            'glass_shatter': (0, 255, 255),
            'lamp_broken': (255, 0, 255),
            'tire_flat': (255, 255, 0),
        }
    
    cv2 = _get_cv2()
    annotated = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
    
    for det in detections:
        x1 = int(det.bbox.x_min)
        y1 = int(det.bbox.y_min)
        x2 = int(det.bbox.x_max)
        y2 = int(det.bbox.y_max)
        
        color = colors.get(det.class_name, (0, 255, 0))
        
        # Draw box
        cv2.rectangle(annotated, (x1, y1), (x2, y2), color, thickness)
        
        # Draw label background
        label = f'{det.class_name}: {det.confidence:.2f}'
        (label_w, label_h), baseline = cv2.getTextSize(
            label, cv2.FONT_HERSHEY_SIMPLEX, font_scale, 1
        )
        
        cv2.rectangle(
            annotated, 
            (x1, y1 - label_h - 10), 
            (x1 + label_w + 4, y1), 
            color, 
            -1
        )
        
        # Draw label text
        cv2.putText(
            annotated, 
            label, 
            (x1 + 2, y1 - 5), 
            cv2.FONT_HERSHEY_SIMPLEX, 
            font_scale, 
            (255, 255, 255), 
            1
        )
    
    return cv2.cvtColor(annotated, cv2.COLOR_BGR2RGB)


def create_damage_heatmap(
    image_size: Tuple[int, int],
    detections: list,
    blur_size: int = 51
) -> np.ndarray:
    """
    Create a heatmap visualization of damage locations.
    
    Args:
        image_size: (width, height) of original image
        detections: List of Detection objects
        blur_size: Gaussian blur kernel size
        
    Returns:
        Heatmap as numpy array
    """
    w, h = image_size
    heatmap = np.zeros((h, w), dtype=np.float32)
    
    for det in detections:
        x1 = int(det.bbox.x_min)
        y1 = int(det.bbox.y_min)
        x2 = int(det.bbox.x_max)
        y2 = int(det.bbox.y_max)
        
        # Add weighted region based on confidence
        heatmap[y1:y2, x1:x2] += det.confidence
    
    # Normalize and blur
    cv2 = _get_cv2()
    if heatmap.max() > 0:
        heatmap = heatmap / heatmap.max()
    
    heatmap = cv2.GaussianBlur(heatmap, (blur_size, blur_size), 0)
    
    # Convert to color heatmap
    heatmap_color = cv2.applyColorMap(
        (heatmap * 255).astype(np.uint8), 
        cv2.COLORMAP_JET
    )
    
    return cv2.cvtColor(heatmap_color, cv2.COLOR_BGR2RGB)
