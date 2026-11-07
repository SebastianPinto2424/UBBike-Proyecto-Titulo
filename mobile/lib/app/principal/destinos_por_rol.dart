import 'package:flutter/material.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

const indiceValidar = 2;
const indiceGestionAdministrador = 3;
const indicePerfil = 4;

bool usaDestinoMiCuenta(RolUsuario rol) => !rol.esUsuarioRegular;

int indiceSoportePorRol(RolUsuario rol) =>
    rol == RolUsuario.administrador ? 1 : 3;

const _destinoInicio = NavigationDestination(
  icon: Icon(Icons.home_outlined),
  selectedIcon: Icon(Icons.home),
  label: 'Inicio',
);

const _destinoSoporte = NavigationDestination(
  icon: Icon(Icons.support_agent_outlined),
  selectedIcon: Icon(Icons.support_agent),
  label: 'Soporte',
);

const _destinoPerfil = NavigationDestination(
  icon: Icon(Icons.person_outline),
  selectedIcon: Icon(Icons.person),
  label: 'Perfil',
);

const _destinoMiCuenta = NavigationDestination(
  icon: Icon(Icons.person_outline),
  selectedIcon: Icon(Icons.person),
  label: 'Mi cuenta',
);

Widget _iconoCentral(IconData icono, double tamano, double relleno) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: relleno, vertical: 6),
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
    child: Icon(icono, color: Colors.white, size: tamano),
  );
}

NavigationDestination _destinoValidar() {
  final icono = _iconoCentral(Icons.qr_code_scanner, 28, 22);
  return NavigationDestination(
    icon: icono,
    selectedIcon: icono,
    label: 'Validar',
  );
}

List<NavigationDestination> destinosPorRol(RolUsuario rol) {
  if (rol == RolUsuario.guardia) {
    return [
      _destinoInicio,
      const NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'Historial',
      ),
      _destinoValidar(),
      const NavigationDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: 'Avisos',
      ),
      _destinoMiCuenta,
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
      _destinoSoporte,
      _destinoMiCuenta,
    ];
  }

  if (rol == RolUsuario.administrador) {
    return [
      _destinoInicio,
      _destinoSoporte,
      _destinoValidar(),
      const NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: 'Gestión',
      ),
      _destinoMiCuenta,
    ];
  }

  final iconoQrUsuario = _iconoCentral(Icons.qr_code_2, 30, 24);
  return [
    _destinoInicio,
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
    _destinoSoporte,
    _destinoPerfil,
  ];
}

List<(IconData, String)> titulosPorRol(RolUsuario rol) {
  if (rol == RolUsuario.guardia) {
    return const [
      (Icons.home_outlined, 'Inicio'),
      (Icons.history_outlined, 'Historial'),
      (Icons.qr_code_scanner, 'Validar'),
      (Icons.support_agent_outlined, 'Avisos'),
      (Icons.person_outline, 'Mi cuenta'),
    ];
  }
  if (rol == RolUsuario.adminCentral) {
    return const [
      (Icons.dashboard_outlined, 'Inicio'),
      (Icons.manage_search_outlined, 'Movimientos'),
      (Icons.security_outlined, 'Guardias'),
      (Icons.support_agent_outlined, 'Soporte'),
      (Icons.person_outline, 'Mi cuenta'),
    ];
  }
  if (rol == RolUsuario.administrador) {
    return const [
      (Icons.home_outlined, 'Inicio'),
      (Icons.support_agent_outlined, 'Soporte'),
      (Icons.qr_code_scanner, 'Validar'),
      (Icons.tune_outlined, 'Gestión'),
      (Icons.person_outline, 'Mi cuenta'),
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
