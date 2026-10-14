/// Ma'lumotlar manbasi sozlamasi.
///
/// Mock:   flutter run -d windows
/// Backend: flutter run -d windows --dart-define=USE_MOCK=false --dart-define=API_URL=http://127.0.0.1:8000
class AppConfig {
  static const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);
  static const String apiBaseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000');
}
