import 'auth_service.dart';
import 'home_service.dart';
import 'notification_service.dart';
import 'theme_service.dart';
import 'user_service.dart';
import 'assistant/chat_agent.dart';

/// All services for a signed-in session, created once and passed to screens.
class AppServices {
  AppServices({required this.auth, required this.theme})
      : home = HomeService(),
        users = UserService(),
        notifications = NotificationService() {
    chat = ChatAgent(home: home);
  }

  final AuthService auth;
  final ThemeService theme;
  final HomeService home;
  final UserService users;
  final NotificationService notifications;
  late final ChatAgent chat;

  void dispose() {
    chat.dispose();
    home.dispose();
  }
}
