# SurveilAI

SurveilAI is a surveillance video analysis application that detects abnormal events in videos using advanced computer vision techniques. The project consists of a **Flutter** frontend for user interaction and a **FastAPI** backend for video processing, leveraging **YOLO** for object detection, **RAFT** for optical flow analysis, and **Google Gemini** for generating human-readable summaries of detected anomalies.

## Features

- **User Authentication**: Secure email/password and Google sign-in using Firebase Authentication.
- **Video Upload and Processing**: Upload videos from the device gallery, processed by the backend to detect abnormal events.
- **Abnormal Event Detection**: Identifies unusual behaviors using YOLO (person detection) and RAFT (motion analysis).
- **Clip Extraction**: Generates short clips of abnormal events with timestamp annotations.
- **Ground Truth Visualization**: Displays anomaly labels as plots for analysis.
- **Summary Generation**: Provides plain-language descriptions of abnormal events using Google Gemini.
- **Responsive UI**: Modern Flutter interface with gradient themes, animations, and video playback.
- **Profile Management**: Edit and view user details (name, mobile number) stored persistently.

## Project Structure

```
SurveilAI/
├── frontend/                    # Flutter frontend code
│   ├── lib/
│   │   ├── edit_profile.dart    # Profile editing screen
│   │   ├── forgot_password_screen.dart # Password reset screen
│   │   ├── loginScreen.dart     # Login screen
│   │   ├── main.dart            # App entry point
│   │   ├── MyHomePage.dart      # Main dashboard
│   │   ├── profile_screen.dart   # Profile display screen
│   │   ├── ResultScreen.dart    # Video processing results
│   │   ├── signupscreen.dart    # Signup screen
│   │   ├── SplashScreen.dart    # Animated splash screen
│   │   └── firebase_options.dart # Firebase configuration
│   ├── assets/                  # Logo and Google icon
│   └── pubspec.yaml             # Flutter dependencies
├── backend/                     # FastAPI backend code
│   ├── fyp.py                   # Main backend script
│   ├── core/                    # RAFT model and utilities (not included)
│   ├── models/                  # YOLO and RAFT model weights
│   ├── NWPU_Campus_gt.npz       # Ground truth dataset
│   └── .env                     # Environment variables
├── README.md                    # This file
└── LICENSE                      # License file (add your preferred license)
```

## Prerequisites

### Frontend
- **Flutter**: Version 3.0.0 or higher
- **Dart**: Version 2.17.0 or higher
- **Firebase Account**: For authentication
- **Android/iOS Emulator or Physical Device**: For testing
- **Dependencies** (listed in `pubspec.yaml`):
  - `firebase_core`
  - `firebase_auth`
  - `google_sign_in`
  - `image_picker`
  - `http`
  - `video_player`
  - `path_provider`
  - `shared_preferences`

### Backend
- **Python**: Version 3.8 or higher
- **Dependencies** (install via `pip`):
  - `fastapi`
  - `uvicorn`
  - `opencv-python`
  - `numpy`
  - `torch`
  - `torchvision`
  - `ultralytics`
  - `Pillow`
  - `matplotlib`
  - `google-genai`
  - `python-dotenv`
  - `pydantic`
- **Pretrained Models**:
  - `yolov8x.pt` (YOLOv8 extra-large)
  - `raft-things.pth` (RAFT optical flow)
- **Google API Key**: For Gemini API
- **Ground Truth Data**: `NWPU_Campus_gt.npz` dataset

## Setup Instructions

### Frontend
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/SurveilAI.git
   cd SurveilAI/frontend
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**:
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
   - Add an Android app to your project and download the `google-services.json` file.
   - Place `google-services.json` in `frontend/android/app/`.
   - Update `frontend/lib/firebase_options.dart` with your Firebase configuration (use FlutterFire CLI for ease):
     ```bash
     flutterfire configure
     ```

4. **Add Assets**:
   - Place `logo.png` and `google.png` in `frontend/assets/`.
   - Update `pubspec.yaml` to include assets:
     ```yaml
     flutter:
       assets:
         - assets/logo.png
         - assets/google.png
     ```

5. **Run the App**:
   ```bash
   flutter run
   ```

### Backend
1. **Navigate to Backend Directory**:
   ```bash
   cd SurveilAI/backend
   ```

2. **Create a Virtual Environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install Dependencies**:
   ```bash
   pip install fastapi uvicorn opencv-python numpy torch torchvision ultralytics Pillow matplotlib google-genai python-dotenv pydantic
   ```

4. **Set Up Environment Variables**:
   - Create a `.env` file in `backend/`:
     ```env
     GOOGLE_API_KEY=your-google-api-key
     ```
   - Obtain a Google API key from [Google Cloud Console](https://console.cloud.google.com) with Gemini API enabled.

5. **Add Pretrained Models**:
   - Place `yolov8x.pt` and `raft-things.pth` in `backend/models/`.
   - Ensure `NWPU_Campus_gt.npz` is in `backend/`.

6. **Run the Backend**:
   ```bash
   python fyp.py
   ```
   - The server runs on `http://0.0.0.0:8000`. Update `MyHomePage.dart` if your backend is hosted elsewhere:
     ```dart
     static const _backendUrl = 'http://your-backend-ip:8000';
     ```

## Usage

1. **Launch the App**:
   - The app starts with a splash screen (`SplashScreen.dart`) displaying the logo and tagline "Crowds Decoded".
   - If logged in, navigates to the dashboard (`MyHomePage.dart`); otherwise, to the login screen (`loginScreen.dart`).

2. **Authentication**:
   - **Login**: Sign in with email/password or Google.
   - **Signup**: Create an account with email, password, name, and mobile number (`signupscreen.dart`).
   - **Forgot Password**: Request a password reset email (`forgot_password_screen.dart`).

3. **Video Processing**:
   - From the dashboard, pick a video from the gallery.
   - The video is uploaded to the backend (`/process_video/`), which detects abnormal events and generates clips, ground truth plots, and a summary.
   - View results in the results screen (`ResultScreen.dart`), including the original video, abnormal clips, ground truth images, and a text summary.

4. **Profile Management**:
   - View and edit user details (name, mobile number) in the profile screen (`profile_screen.dart`, `edit_profile.dart`).
   - Log out to return to the login screen.

## API Endpoints

The backend provides the following endpoints:
- **POST /process_video/**: Upload a video for processing. Returns filenames for the original video, clips, summary, and ground truth images.
- **GET /originals/{filename}**: Stream the original video.
- **GET /clips/{filename}**: Stream an abnormal clip.
- **GET /summaries**: Retrieve the Gemini-generated summary (`summaries.json`).
- **GET /groundtruth/{filename}**: Retrieve a ground truth image.

## Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit changes (`git commit -m 'Add your feature'`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a pull request.

## Issues

- Report bugs or suggest features via the [Issues](https://github.com/your-username/SurveilAI/issues) tab.
- Common issues:
  - Firebase configuration errors: Ensure `google-services.json` and `firebase_options.dart` are correctly set up.
  - Backend connection issues: Verify the backend URL in `MyHomePage.dart` matches your server’s IP/port.
  - Missing models: Ensure `yolov8x.pt`, `raft-things.pth`, and `NWPU_Campus_gt.npz` are in `backend/models/`.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **YOLOv8**: For person detection.
- **RAFT**: For optical flow analysis.
- **Google Gemini**: For summary generation.
- **Flutter**: For the cross-platform frontend.
- **FastAPI**: For the efficient backend.

---

*Built with ❤️ by [Your Name]*  
For questions, contact [your-email@example.com].