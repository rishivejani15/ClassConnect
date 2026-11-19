# Class Connect (Mobile Application)

This is the Flutter mobile application for the Class Connect Adaptive Mastery & Engagement Platform (AMEP).

---

## Overview

Class Connect is a modern, data-driven ed-tech platform designed to support Project-Based Learning (PBL) with structured workflows, real-time engagement tracking, and personalized mastery progression. The platform bridges the gap between traditional classroom teaching and adaptive, student-centric learning.

View the live demo: https://class-connect-web.vercel.app/

---

## Key Features

### Teacher Features

* Create and manage classes with syllabus uploads
* Design PBL collections with AI-generated content
* Define mini-projects and structured step-by-step tasks
* View students enrolled in each mini-project
* Track step completion and submission status
* Monitor real-time student progress via analytics dashboard
* Generate quizzes and evaluate responses using AI
* Track teacher workload and receive productivity insights

### Student Features

* Secure authentication via Firebase
* Browse available mini-projects and select independently
* Follow structured step-by-step tasks with multimedia support
* Submit project work (links, files, images)
* Track personal progress and completion status
* Take quizzes with AI-powered feedback
* Access chatbot assistance for learning support
* Participate in community discussions and Q&A

---

## Technology Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter (Dart) |
| **State Management** | Flutter native (StreamBuilder, FutureBuilder) |
| **UI/UX** | Material 3, custom dark theme |
| **Backend** | Firebase Auth, Cloud Firestore, Firebase Storage |
| **AI Services** | Google Generative AI (Gemini), Groq API |
| **Media** | image_picker, file_picker, video_player |
| **PDF** | syncfusion_flutter_pdf, pdf |
| **Charts** | fl_chart |
| **Notifications** | flutter_local_notifications |
| **Other** | google_mlkit_text_recognition, share_plus |

---

## Getting Started

### Prerequisites

* **Flutter SDK 3.19+**
* **Google Cloud Account** for Firebase services

### Setup

```bash
cd demo

# Install dependencies
flutter pub get

# Configure environment variables
cp .env.example .env
# Add your API keys (see main project README for details)

# Run on device/emulator
flutter run

# Build for platforms
flutter build apk      # Android
flutter build ios      # iOS
flutter build web      # Web
```

---

## Security

Firebase Authentication ensures verified users with role-based access. Firestore rules enforce:

* Students can only modify their own selections and submissions
* Teachers can view and manage all enrolled students
* One mini-project per student per PBL (UID-based enforcement)

For complete documentation, see the [main project README](../README.md).

---

## Resources

* [Firebase Documentation](https://firebase.google.com/docs)
* [Flutter Documentation](https://docs.flutter.dev)