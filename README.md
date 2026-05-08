# Intelligent Vehicle Damage Assessment System

> An end-to-end AI-powered system for automatic vehicle damage detection, repair cost estimation, and interactive AI consultation — built with deep learning, FastAPI, PostgreSQL, and Flutter.

[![Python](https://img.shields.io/badge/Python-3.12-blue?logo=python)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)](https://postgresql.org)
[![License](https://img.shields.io/badge/License-Academic-lightgrey)](./LICENSE)

---

## Features

| Feature | Description |
|---|---|
| **AI Damage Detection** | Detects 6 types of vehicle damage from images and videos |
| **AI Chat Assistant** | Chat with a local Qwen LLM about your specific assessment |
| **Cost Estimation (AUD)** | Itemised repair quote with labour, parts, and 10% GST |
| **Model Comparison** | Benchmarks YOLO11m, YOLOv8m, Faster R-CNN, and RT-DETR |
| **Report Copy** | One-tap clipboard export of full assessment report |
| **Persistent Database** | All assessments and chat histories saved to PostgreSQL |
| **Cross-platform UI** | Flutter app runs on Web, iOS, macOS, and Android |
| **Assessment History** | Browse past assessments with severity and cost summary |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Flutter Frontend                     │
│   (Web / iOS / macOS / Android)                        │
│                                                         │
│  Home ──► Results ──► Ask AI (Chat)                    │
│   │           │            │                            │
│   │     Copy Report    Chat History                     │
│   └───── History Screen ───┘                           │
└───────────────────┬─────────────────────────────────────┘
                    │ HTTP / REST
┌───────────────────▼─────────────────────────────────────┐
│                  FastAPI Backend                         │
│                                                         │
│  /damage/predict    →  YOLO11m / YOLOv8m Inference     │
│  /cost/predict      →  AUD Cost Estimation              │
│  /report/generate   →  Assessment Report + DB Save      │
│  /chat/             →  Qwen LLM via Ollama              │
└──────────┬──────────────────────┬───────────────────────┘
           │                      │
┌──────────▼──────┐    ┌──────────▼──────────────────────┐
│   PostgreSQL    │    │   Ollama (local)                │
│   Assessments  │    │   Qwen 2.5 LLM                  │
│   Chat History │    │   http://localhost:11434         │
└─────────────────┘    └──────────────────────────────────┘
```

---

## Project Structure

```
vehicle_damage_assessment/
├── backend/
│   ├── app/
│   │   ├── main.py                # FastAPI entry point
│   │   ├── config.py              # Settings (loaded from .env)
│   │   ├── db/
│   │   │   ├── database.py        # Async SQLAlchemy engine
│   │   │   └── models.py          # Assessment + chat history table
│   │   ├── models/                # ML model inference wrappers
│   │   ├── routers/
│   │   │   ├── damage.py          # Image & video detection endpoints
│   │   │   ├── cost.py            # AUD cost estimation endpoint
│   │   │   ├── report.py          # Report generation + DB save
│   │   │   └── chat.py            # Qwen AI chat endpoint
│   │   ├── schemas/               # Pydantic request/response models
│   │   └── utils/                 # Utility functions
│   ├── .env                       # Environment configuration (not in git)
│   ├── requirements.txt           # Production dependencies only
│   └── Dockerfile
├── mobile/
│   └── vehicle_damage_app/        # Flutter cross-platform app
│       └── lib/
│           ├── screens/
│           │   ├── home_screen.dart
│           │   ├── results_screen.dart
│           │   ├── chat_screen.dart      # AI conversation UI
│           │   ├── history_screen.dart
│           │   └── settings_screen.dart
│           ├── services/
│           │   ├── api_service.dart      # All HTTP calls
│           │   └── assessment_state.dart # App state management
│           └── models/
│               └── damage_models.dart    # Dart data classes
├── notebooks/
│   ├── model_comparison.ipynb     # Training & evaluation
│   └── requirements.txt           # Training-only dependencies
├── models/                        # Trained .pt weight files
├── configs/
│   └── training_config.yaml
└── README.md
```

---

## Damage Categories

| ID | Category | Description | Base Cost (AUD) |
|----|----------|-------------|-----------------|
| 0 | Dent | Body panel deformation | $350 |
| 1 | Scratch | Surface paint damage | $250 |
| 2 | Crack | Structural cracks | $450 |
| 3 | Glass Shatter | Window/windshield damage | $650 |
| 4 | Lamp Broken | Headlight/taillight damage | $400 |
| 5 | Tire Flat | Tire damage/deflation | $250 |

> Costs are multiplied by severity (small: 1×, medium: 2×, large: 3.5×), plus $120/hr labour and 10% GST.

---

## Model Comparison

| Model | Architecture | Size | Notes |
|-------|-------------|------|-------|
| **YOLO11m** | YOLO v11 Medium | 41 MB | Best accuracy — recommended |
| **YOLOv8m** | YOLO v8 Medium | 52 MB | Balanced speed/accuracy |
| **Faster R-CNN** | ResNet50-FPN v2 | Large | Two-stage baseline |
| **RT-DETR** | Transformer detector | Large | End-to-end transformer |

---

## Setup & Installation

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.12+ | Backend |
| Flutter | 3.x | Frontend |
| Docker Desktop | Latest | PostgreSQL database |
| Ollama | Latest | Local Qwen AI |

---

### 1. Clone the Repository

```bash
git clone https://github.com/BushMar12/Intelligent-Vehicle-Damage-Assessment.git
cd Intelligent-Vehicle-Damage-Assessment
```

### 2. Configure Environment

2.1 Copy and edit the backend config:
```bash
cd backend
```

2.2 Put your model (should be ended with .pt) in ./models directory

2.3 Edit `.env` with your settings:
```env
# Model
MODEL_PATH=../models/<replace your model filename>.pt
MODEL_TYPE=yolo11
CONF_THRESHOLD=0.25
IOU_THRESHOLD=0.45

# PostgreSQL (Docker)
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/vehicledamage

# Qwen AI (Ollama)
LLM_BASE_URL=http://localhost:11434/v1
LLM_API_KEY=ollama
LLM_MODEL=qwen2.5
```

### 3. Start the Qwen AI Model (Local AI)

Download and install [Ollama](https://ollama.com), then:
```bash
ollama run qwen2.5
```
Leave this terminal open — it serves the local AI on port `11434`.

### 4. Start the Database and Backend

**Method A: Using Docker Compose (Recommended - Quickest)**

Make sure Docker Desktop is open, then run from the root directory:
```bash
docker compose up -d
```
*This automatically starts both the PostgreSQL database and the FastAPI backend.* Watch the startup logs with `docker compose logs -f backend`.

**Method B: Manual Setup (Development)**

If you prefer to run components individually:

1. Start PostgreSQL:
```bash
docker run --name car_db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=vehicledamage \
  -p 5432:5432 -d postgres
```
*(Next time after restart: `docker start car_db`)*

2. Start the Backend:
```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

API docs will be available at: **http://localhost:8000/docs**

### 5. Start the Frontend

**Web (quickest):**
```bash
cd mobile/vehicle_damage_app
flutter pub get
flutter build web --release
cd build/web && python3 -m http.server 8080
```
Open **http://localhost:8080**

**iOS/Andriod Simulator:**
```bash
cd mobile/vehicle_damage_app
flutter create --platforms=ios,android .
flutter pub get
flutter devices
flutter run -d # and select your devices
```

**Physical iPhone (must be on same WiFi):**
```bash
flutter run -d <device_id> --release \
  --dart-define=API_BASE_URL=http://<your-mac-ip>:8000
```

---

## API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `GET /health` | GET | Service health + model status |
| `/damage/predict` | POST | Detect damage from image file |
| `/damage/predict/video` | POST | Detect damage from video frames |
| `/cost/predict` | POST | Estimate AUD repair costs |
| `/report/generate` | POST | Generate report + save to database |
| `/chat/` | POST | Chat with Qwen AI about assessment |

**Example — Detect damage:**
```bash
curl -X POST "http://localhost:8000/damage/predict" \
  -F "file=@damaged_car.jpg"
```

**Example — Chat with AI:**
```bash
curl -X POST "http://localhost:8000/chat/" \
  -H "Content-Type: application/json" \
  -d '{"assessment_id": "ABC12345", "message": "Is the crack in the windshield dangerous?"}'
```

---

## Database

Assessments and chat conversations are persisted to PostgreSQL automatically.

### View the database (GUI)

Use **[TablePlus](https://tableplus.com/)** (free) with these settings:
- **Host:** `localhost` | **Port:** `5432`
- **User:** `postgres` | **Password:** `postgres`
- **Database:** `vehicledamage`

### `assessments` Table Schema

| Column | Type | Description |
|--------|------|-------------|
| `id` | String (UUID) | Report ID |
| `created_at` | DateTime | Timestamp |
| `detections_json` | JSON | ML detection results |
| `cost_estimation_json` | JSON | AUD cost breakdown |
| `report_json` | JSON | Full assessment report |
| `chat_history` | JSON | Conversation history with Qwen |

---

### View the database (Docker CLI)

Open a terminal and drop into an interactive SQL shell directly inside the container:

```bash
/Applications/Docker.app/Contents/Resources/bin/docker exec -it vehicle_db psql -U postgres -d vehicledamage
```

> **Note:** If `docker` is on your PATH (e.g. after running Docker Desktop), you can use `docker exec -it vehicle_db psql -U postgres -d vehicledamage` directly.

**Useful queries once inside `psql`:**

```sql
-- List all tables
\dt

-- View all assessments (summary)
SELECT id, created_at FROM assessments ORDER BY created_at DESC;

-- View damage types and count per assessment
SELECT id,
       created_at,
       jsonb_array_length(detections_json::jsonb) AS damage_count,
       detections_json::json->0->>'class_name'    AS first_damage
FROM assessments
ORDER BY created_at DESC;

-- Show only assessments that have AI chat history
SELECT id, created_at, chat_history
FROM assessments
WHERE chat_history != '[]'
ORDER BY created_at DESC;

-- Exit psql
\q
```

---

## Technologies

| Layer | Technology |
|-------|-----------|
| **Deep Learning** | PyTorch, Ultralytics YOLO |
| **Backend API** | FastAPI, Uvicorn, Pydantic v2 |
| **Database** | PostgreSQL, SQLAlchemy 2.0 (async), asyncpg |
| **AI Chat** | Qwen 2.5 via Ollama (OpenAI-compatible API) |
| **Frontend** | Flutter 3, Dart |
| **Image Processing** | OpenCV, Pillow |
| **Device Support** | CUDA (NVIDIA), Apple MPS, CPU |

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Web | ✅ Supported | Chrome, Firefox, Safari, Edge |
| iOS | ✅ Supported | macOS + Xcode required to build |
| macOS | ✅ Supported | Native desktop app |
| Android | 🔧 Configured | Requires Android Studio setup |

---

## Academic Context

This project was developed as **Assignment 3** for the UTS Master's subject:
> **42028 — Deep Learning and Convolutional Neural Networks**

It demonstrates a complete, production-aware ML pipeline from model training and evaluation through to full-stack web/mobile deployment with a persistent backend and generative AI integration.

---

## 📄 License

For educational purposes as part of the UTS Master's program.

## Acknowledgements

- [CarDD Dataset](https://github.com/CarDD-USTC/CarDD-USTC.github.io) — vehicle damage training images
- [Ultralytics](https://ultralytics.com) — YOLO implementations
- [Ollama](https://ollama.com) — local LLM serving
- UTS Faculty of Engineering and IT
