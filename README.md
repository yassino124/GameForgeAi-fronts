# GameForge AI - Flutter Mobile App

A revolutionary SaaS platform that uses artificial intelligence to automatically generate ready-to-deploy games. This comprehensive Flutter mobile application allows users to create, customize, and deploy games entirely from their mobile device.

## Features

### Onboarding Flow
- **Splash Screen**: Animated logo with particle effects and gradient background
- **Welcome Screen**: Hero illustration with compelling call-to-action
- **Feature Highlights**: Interactive carousel showcasing AI capabilities
- **Permission Request**: Friendly permission handling for camera, storage, and microphone

### Authentication System
- **Sign In**: Email/password with social login (Google, Apple)
- **Sign Up**: Registration with password strength indicator
- **Email Verification**: Animated verification process with countdown timer
- **Password Recovery**: Secure password reset functionality

### Main Dashboard
- **Stats Overview**: Projects, generations, builds, and downloads
- **Quick Actions**: Create new game and browse templates
- **Recent Projects**: Visual project cards with progress indicators
- **Bottom Navigation**: Home, Projects, Templates, Profile tabs

### Project Creation Flow
- **Template Selection**: Browse and filter game templates by category
- **Project Details**: Configure name, description, tags, and advanced settings
- **AI Configuration**: Choose AI models, creativity level, and features
- **Generation Progress**: Real-time progress with animated steps and minimization

### Build & Deployment
- **Platform Selection**: iOS, Android, Web, Windows, macOS, Linux
- **Build Configuration**: Version control, bundle ID, assets upload
- **Build Progress**: Multi-platform build tracking with logs
- **Build Results**: Download links, QR codes, and sharing options

### Template Marketplace
- **Featured Templates**: Highlighted premium templates carousel
- **Search & Filter**: Advanced search with category and sorting options
- **Template Details**: Ratings, downloads, creator information
- **Grid/List View**: Toggle between different viewing modes

### Profile & Settings
- **User Profile**: Avatar, stats, achievements, and activity
- **Subscription Management**: Plan comparison, payment methods, billing history
- **Settings**: Account, privacy, notifications, and app preferences
- **Support**: Help center, contact support, bug reporting

### Notifications & Messaging
- **Notification Center**: Categorized notifications with filtering
- **In-App Messages**: Real-time chat with support team
- **Quick Replies**: Predefined responses for common questions
- **Push Notifications**: Configurable notification preferences

## Design System

### Color Palette
- **Primary**: #6366F1 (Indigo)
- **Secondary**: #8B5CF6 (Purple)
- **Accent**: #06B6D4 (Cyan)
- **Success**: #10B981 (Green)
- **Warning**: #F59E0B (Amber)
- **Error**: #EF4444 (Red)
- **Background**: #0F172A (Dark)
- **Surface**: #1E293B (Cards/Modals)

### Typography
- **Font Family**: Inter (SF Pro for iOS, Roboto for Android)
- **Headings**: Bold, 24-32px
- **Subheadings**: SemiBold, 18-20px
- **Body**: Regular, 14-16px
- **Caption**: Regular, 12px

### Component Library
- **Buttons**: Primary, Secondary, Ghost, Danger, Success variants
- **Cards**: Project cards, stats cards, template cards
- **Inputs**: Text fields, password fields, search fields
- **Navigation**: Bottom tabs, app bars, side drawers
- **Feedback**: Loading states, empty states, error states

## Architecture

### MVVM Pattern
- **Models**: Data entities and business logic
- **Views**: UI components and screens
- **ViewModels**: State management and data transformation

### Project Structure
```
lib/
├── core/
│   ├── constants/     # App constants (colors, typography, etc.)
│   ├── themes/        # App themes and styling
│   ├── router/        # Navigation configuration
│   └── utils/         # Utility functions
├── data/
│   ├── models/        # Data models
│   ├── repositories/  # Data repositories
│   └── datasources/   # Data sources (API, local storage)
├── domain/
│   ├── entities/      # Domain entities
│   ├── repositories/  # Repository interfaces
│   └── usecases/      # Business logic use cases
└── presentation/
    ├── providers/     # State management (Provider/Riverpod)
    ├── widgets/       # Reusable UI components
    └── screens/       # App screens
```

## Dependencies

### Core Dependencies
- `flutter`: Flutter framework
- `go_router`: Navigation and routing
- `provider` & `flutter_riverpod`: State management
- `firebase_core` & `firebase_auth`: Authentication
- `google_sign_in`: Google authentication

### UI & Animation
- `lottie`: Animation library
- `flutter_staggered_animations`: Staggered animations
- `cached_network_image`: Image caching
- `shimmer`: Loading shimmer effects

### Utilities
- `http`: HTTP requests
- `shared_preferences`: Local storage
- `permission_handler`: Device permissions
- `image_picker`: Image selection
- `url_launcher`: URL launching
- `qr_flutter`: QR code generation
- `font_awesome_flutter` & `lucide_icons`: Icon libraries

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.10.7)
- Dart SDK
- Android Studio / VS Code
- Firebase project configuration

### Installation
1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Configure Firebase:
   - Add `google-services.json` (Android)
   - Add `GoogleService-Info.plist` (iOS)
4. Run the app:
   ```bash
   flutter run
   ```

### Build Commands
```bash
# Debug build
flutter run

# Release build
flutter build apk --release
flutter build ios --release

# Web build
flutter build web --release
```

## Platform Support

- **iOS**: iOS 12.0+
- **Android**: Android 5.0+ (API 21+)
- **Web**: Modern browsers (Chrome, Safari, Firefox, Edge)
- **Desktop**: Windows 10+, macOS 10.14+, Linux (Ubuntu 18.04+)

## Configuration

### Environment Variables
Create a `.env` file in the root directory:
```
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
```

### Firebase Configuration
1. Create a Firebase project
2. Enable Authentication (Email, Google, Apple)
3. Configure Firestore for data storage
4. Set up Firebase Cloud Messaging for push notifications

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and questions:
- Email: support@gameforge.ai
- In-app chat: Available 24/7
- Documentation: docs.gameforge.ai
- Bug Reports: GitHub Issues

## Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- All contributors and beta testers
- The open-source community

---

**GameForge AI** - Create Games with AI Magic 
