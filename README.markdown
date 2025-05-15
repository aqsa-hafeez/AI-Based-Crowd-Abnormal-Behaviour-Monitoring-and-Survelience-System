# AI-based Crowd Abnormal Behavior Monitoring and Surveillance System

## Overview
This repository contains the implementation of an **AI-based Crowd Abnormal Behavior Monitoring and Surveillance System**, a final year project for the Bachelor of Science in Artificial Intelligence at COMSATS University Islamabad, Attock Campus. The system is a Flutter-based mobile application designed for security personnel to monitor and detect abnormal behaviors in crowded environments such as stadiums, airports, and city squares. It leverages advanced AI models—YOLOv8, RAFT, and Gemini 2.0 Flash—for person detection, motion analysis, and behavior classification, respectively.

## Features
- **User Authentication**: Secure sign-up, sign-in, and password recovery using Firebase Authentication.
- **Video Upload and Processing**: Users can upload videos (MP4, AVI) from their Android device, which are processed to detect and classify abnormal crowd behaviors.
- **AI Pipeline**:
  - **YOLOv8**: Detects individuals in video frames, marking them with green bounding boxes.
  - **RAFT**: Analyzes motion patterns to identify abnormalities, highlighting them with red bounding boxes.
  - **Gemini 2.0 Flash**: Classifies abnormal behaviors (e.g., sudden movements, aggressive actions) and generates summaries.
- **Result Display**: Presents processed videos, abnormal clips, ground truth annotations (if available), and classification results in a user-friendly interface.
- **Offline Processing**: Backend processing runs on a local host, ensuring data privacy and functionality without internet dependency.
- **Dataset**: Utilizes the **CampusVAD** dataset for training and evaluation, covering diverse crowd scenarios.

## Project Structure
```
├── client_mobile_app/           # Flutter-based Android application
│   ├── lib/                     # Flutter source code
│   ├── android/                 # Android-specific configurations
│   └── pubspec.yaml            # Flutter dependencies
├── local_host_processor/        # Backend video processing pipeline
│   ├── scripts/                 # Python scripts for YOLOv8, RAFT, and Gemini 2.0 Flash
│   ├── models/                  # Pre-trained model weights
│   └── requirements.txt         # Python dependencies
├── docs/                        # Project documentation
│   ├── BS_Final_Project_Document.pdf  # Full project report
│   └── diagrams/                # UML diagrams (Use Case, Class, Sequence, etc.)
├── dataset/                     # Sample data from CampusVAD (if included)
└── README.md                    # This file
```

## Installation
### Prerequisites
- **Flutter**: Version 3.27.0
- **Python**: Version 3.10.12
- **Android Device/Emulator**: For running the mobile app
- **Local Host with GPU**: For video processing (recommended: NVIDIA GPU with CUDA support)
- **Dependencies**:
  - Flutter: `flutter pub get`
  - Python: `pip install -r local_host_processor/requirements.txt`

### Setup
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/crowd-abnormal-behavior-monitoring.git
   cd crowd-abnormal-behavior-monitoring
   ```

2. **Mobile App Setup**:
   - Navigate to `client_mobile_app/`.
   - Install Flutter dependencies:
     ```bash
     flutter pub get
     ```
   - Connect an Android device or emulator.
   - Run the app:
     ```bash
     flutter run
     ```

3. **Backend Setup**:
   - Navigate to `local_host_processor/`.
   - Install Python dependencies:
     ```bash
     pip install -r requirements.txt
     ```
   - Ensure pre-trained models (YOLOv8, RAFT) are placed in `local_host_processor/models/`.
   - Configure the Google Gemini API key in the script (see `scripts/gemini_config.py`).
   - Run the backend server:
     ```bash
     python scripts/main.py
     ```

4. **Firebase Configuration**:
   - Set up a Firebase project and enable Authentication.
   - Add the `google-services.json` file to `client_mobile_app/android/app/`.
   - Update Firebase rules to allow secure access.

## Usage
1. **Launch the App**: Open the Flutter app on your Android device.
2. **Sign Up/Sign In**: Create an account or log in using your credentials.
3. **Upload Video**: From the Home Page, select a video (MP4 or AVI) from your gallery.
4. **View Results**: After processing, review the results, including:
   - Original video with green (person) and red (abnormal) bounding boxes.
   - Clips of abnormal events.
   - Classification labels (e.g., "Sudden Movement").
   - Ground truth annotations (if available).

## Tools and Technologies
| Tool/Technology         | Version       | Purpose                              |
|-------------------------|---------------|--------------------------------------|
| Flutter                 | 3.27.0        | Mobile app development               |
| Python                  | 3.10.12       | Backend video processing             |
| OpenCV                  | 4.10.0        | Video frame handling                 |
| PyTorch                 | 2.4.0+cu121   | Running YOLOv8 and RAFT models       |
| Ultralytics YOLO        | YOLOv8       | Person detection                     |
| RAFT Model              | RAFT-sintel   | Abnormality detection via optical flow |
| Google Gemini API       | Gemini 2.0 Flash | Behavior classification            |

## Testing
The system was rigorously tested, as detailed in the project report:
- **Unit Testing**: Validated individual modules (e.g., YOLOv8 detection, RAFT motion analysis).
- **Functional Testing**: Ensured end-to-end functionality (e.g., video upload, result display).
- **Business Rules Testing**: Verified constraints like password policies and supported video formats.
- **Integration Testing**: Confirmed seamless interaction between the mobile app and backend pipeline.

All test cases passed, ensuring reliability and usability. Refer to `docs/BS_Final_Project_Document.pdf` for detailed test results.

## Dataset
The system uses the **CampusVAD** dataset, which includes labeled crowd scenarios from transportation hubs, stadiums, and city squares. It supports semi-supervised learning with annotations for anomalies like sudden movements and aggressive actions. Due to size constraints, the dataset is not included in this repository but can be accessed [here](#) (replace with actual link if available).

## Future Work
- **Real-time Processing**: Optimize for live video streaming using frame subsampling and GPU acceleration.
- **Multi-modal Analysis**: Incorporate audio data for enhanced behavior detection.
- **Edge Deployment**: Optimize models for resource-constrained devices using quantization and pruning.
- **Enhanced UI**: Add interactive heatmaps and predictive analytics for better insights.

## Contributors
- **Aqsa Hafeez** (CIIT/FA21-BAI-031/ATK)
- **Muhammad Usama** (CIIT/FA21-BAI-061/ATK)
- **Supervisor**: Dr. Muazzam Maqsood, Associate Professor, COMSATS University Islamabad, Attock Campus

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments
We express gratitude to our supervisor, Dr. Muazzam Maqsood, and the faculty of the Department of Computer Science at COMSATS University Islamabad, Attock Campus, for their guidance and support. Special thanks to our families and friends for their encouragement.

For detailed documentation, refer to `docs/BS_Final_Project_Document.pdf`.