import 'package:flutter/material.dart';

import '../config/team.dart';

/// One student's hardware module (shown as its own card / section).
class ModuleInfo {
  const ModuleInfo({
    required this.id,
    required this.name,
    required this.owner,
    required this.icon,
    required this.hardware,
  });

  final String id;
  final String name;
  final String owner;
  final IconData icon;

  /// Sensors and actuators, for the module card.
  final String hardware;

  static const garage = ModuleInfo(
    id: 'garage',
    name: 'Smart garage',
    owner: Team.garage,
    icon: Icons.garage_outlined,
    hardware: 'HC-SR04 ultrasonic · servo',
  );
  static const clothesLine = ModuleInfo(
    id: 'clothesLine',
    name: 'Clothes line',
    owner: Team.clothesLine,
    icon: Icons.dry_cleaning,
    hardware: 'Rain sensor · servo',
  );
  static const fireAlarm = ModuleInfo(
    id: 'fire',
    name: 'Fire alarm',
    owner: Team.fireAlarm,
    icon: Icons.local_fire_department_outlined,
    hardware: 'Flame sensor · buzzer',
  );
  static const fan = ModuleInfo(
    id: 'fan',
    name: 'Fan',
    owner: Team.fan,
    icon: Icons.mode_fan_off_outlined,
    hardware: 'Relay module',
  );
  static const lights = ModuleInfo(
    id: 'lights',
    name: 'General control lights',
    owner: Team.lights,
    icon: Icons.lightbulb_outline,
    hardware: '3 LEDs',
  );

  static const all = [garage, clothesLine, fireAlarm, fan, lights];
}
