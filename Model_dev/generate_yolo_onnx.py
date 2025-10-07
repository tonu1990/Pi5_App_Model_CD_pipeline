from ultralytics import YOLO
import os

# Paths
script_dir = os.path.dirname(os.path.abspath(__file__))
inbox_dir = os.path.join(script_dir, "artifacts2")

# Make sure inbox exists
os.makedirs(inbox_dir, exist_ok=True)

# Load pretrained YOLOv8 small
model = YOLO("yolov8s.pt")

# Export to ONNX (this creates yolov8.onnx in current working dir)
exported_file = model.export(format="onnx", opset=12)

# Move it to artifacts/
onnx_target = os.path.join(inbox_dir, "yolov8s.onnx")
os.replace(exported_file, onnx_target)
print(f"ONNX model saved to: {onnx_target}")
      