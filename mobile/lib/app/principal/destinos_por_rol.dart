import 'package:flutter/material.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

List<NavigationDestination> destinosPorRol(RolUsuario rol) {
  final iconoQrGuardia = Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
    decoration: BoxDecoration(
      color: ColoresUbb.azulApp,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: ColoresUbb.azulApp.withValues(alpha: 0.3),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
  );

  final iconoQrUsuario = Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
    decoration: BoxDecoration(
      color: ColoresUbb.azulApp,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: ColoresUbb.azulApp.withValues(alpha: 0.3),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: const Icon(Icons.qr_code_2, color: Colors.white, size: 30),
  );

  if (rol == RolUsuario.guardia) {
    return [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Inicio',
      ),
      const NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'Historial',
      ),
      NavigationDestination(
        icon: iconoQrGuardia,
        selectedIcon: iconoQrGuardia,
        label: 'Validar',
      ),
      const NavigationDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: 'Avisos',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];
  }

  if (rol == RolUsuario.adminCentral) {
    return const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Inicio',
      ),
      NavigationDestination(
        icon: Icon(Icons.manage_search_outlined),
        selectedIcon: Icon(Icons.manage_search),
        label: 'Movimientos',
      ),
      NavigationDestination(
        icon: Icon(Icons.security_outlined),
        selectedIcon: Icon(Icons.security),
        label: 'Guardias',
      ),
      NavigationDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: 'Soporte',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];
  }

  if (rol == RolUsuario.administrador) {
    return [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Inicio',
      ),
      const NavigationDestination(
        icon: Icon(Icons.pedal_bike_outlined),
        selectedIcon: Icon(Icons.pedal_bike),
        label: 'Bicicletas',
      ),
      const NavigationDestination(
        icon: Icon(Icons.qr_code_scanner_outlined),
        selectedIcon: Icon(Icons.qr_code_scanner),
        label: 'Validar',
      ),
      const NavigationDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: 'Soporte',
      ),
      const NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: 'Gestión',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];
  }

  return [
    const NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Inicio',
    ),
    const NavigationDestination(
      icon: Icon(Icons.pedal_bike_outlined),
      selectedIcon: Icon(Icons.pedal_bike),
      label: 'Bicicletas',
    ),
    NavigationDestination(
      icon: iconoQrUsuario,
      selectedIcon: iconoQrUsuario,
      label: 'QR',
    ),
    const NavigationDestination(
      icon: Icon(Icons.support_agent_outlined),
      selectedIcon: Icon(Icons.support_agent),
      label: 'Soporte',
    ),
    const NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Perfil',
    ),
  ];
}

List<(IconData, String)> titulosPorRol(RolUsuario rol) {
  if (rol == RolUsuario.guardia) {
    return const [
      (Icons.home_outlined, 'Inicio'),
      (Icons.history_outlined, 'Historial'),
      (Icons.qr_code_scanner, 'Validar'),
      (Icons.support_agent_outlined, 'Avisos'),
      (Icons.person_outline, 'Perfil'),
    ];
  }
  if (rol == RolUsuario.adminCentral) {
    return const [
      (Icons.dashboard_outlined, 'Inicio'),
      (Icons.manage_search_outlined, 'Movimientos'),
      (Icons.security_outlined, 'Guardias'),
      (Icons.support_agent_outlined, 'Soporte'),
      (Icons.person_outline, 'Perfil'),
    ];
  }
  if (rol == RolUsuario.administrador) {
    return const [
      (Icons.home_outlined, 'Inicio'),
      (Icons.pedal_bike_outlined, 'Bicicletas'),
      (Icons.qr_code_scanner, 'Validar'),
      (Icons.support_agent_outlined, 'Soporte'),
      (Icons.tune_outlined, 'Gestión'),
      (Icons.person_outline, 'Perfil'),
    ];
  }
  return const [
    (Icons.home_outlined, 'Inicio'),
    (Icons.pedal_bike_outlined, 'Bicicletas'),
    (Icons.qr_code_2, 'QR'),
    (Icons.support_agent_outlined, 'Soporte'),
    (Icons.person_outline, 'Perfil'),
  ];
}
