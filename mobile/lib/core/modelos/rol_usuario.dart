enum RolUsuario {
  estudiante,
  funcionario,
  guardia,
  adminCentral,
  administrador
}

extension EtiquetaRolUsuario on RolUsuario {
  static RolUsuario desdeApi(String valor) {
    switch (valor.toUpperCase()) {
      case 'FUNCIONARIO':
        return RolUsuario.funcionario;
      case 'GUARDIA':
        return RolUsuario.guardia;
      case 'ADMIN_CENTRAL':
        return RolUsuario.adminCentral;
      case 'ADMINISTRADOR':
        return RolUsuario.administrador;
      case 'ESTUDIANTE':
      default:
        return RolUsuario.estudiante;
    }
  }

  String get valorApi {
    switch (this) {
      case RolUsuario.estudiante:
        return 'ESTUDIANTE';
      case RolUsuario.funcionario:
        return 'FUNCIONARIO';
      case RolUsuario.guardia:
        return 'GUARDIA';
      case RolUsuario.adminCentral:
        return 'ADMIN_CENTRAL';
      case RolUsuario.administrador:
        return 'ADMINISTRADOR';
    }
  }

  String get etiqueta {
    switch (this) {
      case RolUsuario.estudiante:
        return 'Estudiante';
      case RolUsuario.funcionario:
        return 'Funcionario';
      case RolUsuario.guardia:
        return 'Guardia';
      case RolUsuario.adminCentral:
        return 'Admin central';
      case RolUsuario.administrador:
        return 'Administrador';
    }
  }

  bool get esUsuarioRegular {
    return this == RolUsuario.estudiante || this == RolUsuario.funcionario;
  }
}
