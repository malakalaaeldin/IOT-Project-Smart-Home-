import 'package:flutter/material.dart';

import '../config/team.dart';
import '../models/app_user.dart';
import '../models/module_info.dart';
import '../services/app_services.dart';
import '../services/notification_service.dart';

/// Account, role, dark mode, notifications, user roles (admin) and sign out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.services, required this.me});
  final AppServices services;
  final AppUser? me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = services.notifications;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(me?.email ?? services.auth.currentUser?.email ?? ''),
            subtitle: Text(me?.isAdmin == true ? 'Admin' : 'User'),
            trailing: Chip(
              label: Text(me?.isAdmin == true ? 'ADMIN' : 'USER'),
              avatar: Icon(me?.isAdmin == true
                  ? Icons.admin_panel_settings
                  : Icons.person_outline),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Appearance', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: services.theme,
          builder: (context, _) => SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('System')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
            ],
            selected: {services.theme.mode},
            onSelectionChanged: (s) => services.theme.setMode(s.first),
          ),
        ),
        const SizedBox(height: 16),
        Text('Notifications', style: theme.textTheme.titleMedium),
        Card(
          child: Column(children: [
            ListTile(
              leading: Icon(n.pushReady ? Icons.notifications_active : Icons.notifications_off,
                  color: n.pushReady ? Colors.green : Colors.orange),
              title: Text(n.pushReady ? 'Push alerts on' : 'Push alerts unavailable'),
              subtitle: Text(n.pushReady
                  ? 'Fire and rain alerts arrive even when the app is closed.'
                  : 'Alerts still show while the app is open. ${n.pushError ?? ''}'),
            ),
            ListTile(
              leading: const Icon(Icons.notification_add_outlined),
              title: const Text('Send a test notification'),
              onTap: () => n.show(NotificationService.idFire, 'Test alert',
                  'This is how a fire alert will look.'),
            ),
          ]),
        ),
        if (me?.isAdmin == true) ...[
          const SizedBox(height: 16),
          Text('Users and roles', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Admins can change automation and schedules.', style: theme.textTheme.bodySmall),
          _UsersList(services: services, myUid: me!.uid),
        ],
        const SizedBox(height: 16),
        Text('Team', style: theme.textTheme.titleMedium),
        Card(
          child: Column(children: [
            for (final m in ModuleInfo.all)
              ListTile(
                dense: true,
                leading: Icon(m.icon),
                title: Text(m.name),
                subtitle: Text(m.hardware),
                trailing: Text(m.owner),
              ),
            const ListTile(
              dense: true,
              leading: Icon(Icons.phone_android),
              title: Text('Mobile app'),
              trailing: Text(Team.mobileApp),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('signOutButton'),
          onPressed: () => services.auth.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _UsersList extends StatefulWidget {
  const _UsersList({required this.services, required this.myUid});
  final AppServices services;
  final String myUid;

  @override
  State<_UsersList> createState() => _UsersListState();
}

class _UsersListState extends State<_UsersList> {
  late final Stream<List<AppUser>> _users = widget.services.users.watchAll();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _users,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Card(child: ListTile(title: Text("Couldn't load users")));
        }
        if (!snap.hasData) {
          return const Padding(
              padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        return Card(
          child: Column(children: [
            for (final u in snap.data!)
              SwitchListTile(
                secondary: Icon(u.isAdmin ? Icons.admin_panel_settings : Icons.person_outline),
                title: Text(u.email.isEmpty ? u.uid : u.email),
                subtitle: Text(u.isAdmin ? 'Admin' : 'User'),
                value: u.isAdmin,
                // You can't demote yourself (avoids locking out the last admin).
                onChanged: u.uid == widget.myUid
                    ? null
                    : (v) => widget.services.users.setRole(u.uid, v ? 'admin' : 'user'),
              ),
          ]),
        );
      },
    );
  }
}
