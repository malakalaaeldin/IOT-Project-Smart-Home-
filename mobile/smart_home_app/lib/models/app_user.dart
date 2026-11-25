/// A signed-in user and their role, from `/users/{uid}`.
///
/// Roles: `admin` can change automation settings, schedules and other users'
/// roles; `user` can view and control devices.
class AppUser {
  const AppUser({required this.uid, required this.email, required this.role});

  final String uid;
  final String email;
  final String role;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(String uid, Map<String, dynamic> m, {String? fallbackEmail}) =>
      AppUser(
        uid: uid,
        email: (m['email'] ?? fallbackEmail ?? '').toString(),
        role: m['role'] == 'admin' ? 'admin' : 'user',
      );
}
