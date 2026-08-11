# CafeFlow - Coffee Shop Employee Scheduling Platform

A production-ready Flutter & Firebase mobile application for managing staff scheduling across multiple coffee shop locations (Gara & Avantgarden).

## Features

- **Google Sign-In Authentication** - Secure login with Firebase
- **Smart Scheduling Engine** - Automatic shift generation with capacity validation
- **Real-time Calendar** - Visual availability with color-coded occupancy states
- **Employee Dashboard** - Hours tracking, upcoming shifts, location breakdown
- **Admin Dashboard** - Schedule management, vacation approval, team oversight
- **Vacation System** - Request/approval workflow with hour counting
- **Consumption Tracking** - Log and manage employee consumptions
- **FCM Notifications** - Shift reminders and schedule updates

## Quick Start

1. Install dependencies: `flutter pub get`
2. Configure Firebase: `flutterfire configure`
3. Run app: `flutter run`

## Documentation

- [Setup Guide](SETUP_GUIDE.md) - Complete environment setup
- [Firestore Schema](FIRESTORE_SCHEMA.md) - Database structure

## Architecture

- **State Management:** Riverpod
- **Database:** Firestore
- **Authentication:** Firebase Auth + Google Sign-In
- **Notifications:** Firebase Cloud Messaging

## Deployment

- **Android:** APK signing for direct distribution
- **iOS:** Codemagic cloud builds (TestFlight/Ad-Hoc)

## Business Rules

- Max 22 hours/day per location
- Max 2 concurrent employees
- Operating hours: 07:00-18:00
- Vacation days count as 11 worked hours

## License

Private - Internal use only
