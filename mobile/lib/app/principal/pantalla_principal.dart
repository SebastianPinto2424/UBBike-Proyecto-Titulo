import 'dart:async';
import 'package:ubbike/shared/utilidades/refresco_coalescido.dart';
import 'package:ubbike/core/providers/conexion_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/core/servicios/fcm_servicio.dart';
import 'package:ubbike/core/servicios/tiempo_real_servicio.dart';
import 'package:ubbike/features/incidencias/application/incidencias_vm.dart';
import 'package:ubbike/features/notificaciones/application/controlador_notificaciones.dart';
import 'package:ubbike/features/notificaciones/presentation/pantalla_notificaciones.dart';
import 'package:ubbike/shared/modelos/notificacion_app.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/shared/widgets/contenedor_responsivo.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

import 'package:ubbike/features/inicio/presentation/vista_inicio_usuario.dart';
import 'package:ubbike/features/bicicletas/presentation/vista_bicicletas_usuario.dart';
import 'package:ubbike/features/qr/application/qr_usuario_vm.dart';
import 'package:ubbike/features/qr/presentation/vista_qr_usuario.dart';
import 'package:ubbike/features/acceso/presentation/vista_inicio_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_ingreso_guardia.dart';
import 'package:ubbike/features/inicio/presentation/vista_tablero_central.dart';
import 'package:ubbike/features/inicio/presentation/vista_tablero_administrador.dart';
import 'package:ubbike/features/admin/presentation/vista_gestion_bicicleteros.dart';
import 'package:ubbike/features/admin/presentation/vista_gestion_usuarios.dart';
import 'package:ubbike/app/principal/vista_menu_gestion.dart';
import 'package:ubbike/features/historial/presentation/vista_movimientos_central.dart';
import 'package:ubbike/app/principal/aviso_notificacion.dart';
import 'package:ubbike/app/principal/destino_inicial.dart';
import 'package:ubbike/app/principal/destinos_por_rol.dart';
import 'package:ubbike/app/principal/puente_tiempo_real.dart';
import 'package:ubbike/app/principal/vista_soporte.dart';
import 'package:ubbike/features/perfil/presentation/pantalla_principal_perfil.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/features/historial/presentation/vista_movimientos_usuario.dart';

class PantallaPrincipal extends ConsumerStatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  ConsumerState<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends ConsumerState<PantallaPrincipal>
    with WidgetsBindingObserver {
  int indice = 0;
  ModoIngresoGuardia modoIngresoGuardia = ModoIngresoGuardia.qr;
  int tabSoporte = 0;
  int tabBicicletas = 0;
  int navegacionesBicicletas = 0;
  RolUsuario? rolPaginas;
  Set<int> indicesVisitados = {0};
  late final ControladorNotificaciones controladorNotificaciones;
  late final PuenteTiempoReal puenteTiempoReal;

  TiempoRealServicio get tiempoRealService => puenteTiempoReal.servicio;

  void _seleccionarIndice(int nuevoIndice) {
    setState(() {
      indice = nuevoIndice;
      indicesVisitados.add(nuevoIndice);
    });
  }

  void _abrirIngresoGuardia(ModoIngresoGuardia modo) {
    setState(() {
      modoIngresoGuardia = modo;
      indice = 2;
      indicesVisitados.add(2);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RefrescoCoalescido.aplicacionActiva = true;
    puenteTiempoReal = PuenteTiempoReal(
      alCambiarConexion: (estado) {
        RefrescoCoalescido.socketConectado = estado == EstadoConexion.conectado;
        Future.microtask(() {
          if (mounted) ref.read(conexionProvider.notifier).state = estado;
        });
      },
      alCambiarVersion: (version) {
        if (mounted) ref.read(version.notifier).state++;
      },
      alEventoQr: (datos) {
        if (mounted) ref.read(eventoQrProvider.notifier).recibir(datos);
      },
      alCerrarSesionRemota: (motivo) =>
          ref.read(sesionProvider.notifier).cerrarPorAvisoDelServidor(motivo),
      alRenovarSesion: () => ref.read(sesionProvider.notifier).renovarSesion(),
    );
    controladorNotificaciones =
        ref.read(crearControladorNotificacionesProvider)(
      tiempoRealService.notificaciones,
    );
    controladorNotificaciones.addListener(_sincronizarNotificaciones);
    controladorNotificaciones.iniciar();
    FcmServicio.instancia.notificacionTocada.addListener(_alTocarPush);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sincronizarTiempoRealConSesion(ref.read(sesionProvider).value);
        _alTocarPush();
        ref.read(incidenciaPendienteAlIniciarProvider.notifier).state = false;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controladorNotificaciones.removeListener(_sincronizarNotificaciones);
    controladorNotificaciones.dispose();
    FcmServicio.instancia.notificacionTocada.removeListener(_alTocarPush);
    puenteTiempoReal.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final oculta = estado == AppLifecycleState.paused ||
        estado == AppLifecycleState.hidden;
    RefrescoCoalescido.aplicacionActiva = !oculta;

    if (estado == AppLifecycleState.resumed) {
      _sincronizarTiempoRealConSesion(ref.read(sesionProvider).valueOrNull);
      controladorNotificaciones.actualizar();
      _forzarRefrescoPantallas();
    } else if (oculta) {
      tiempoRealService.desconectar();
    }
  }

  void _forzarRefrescoPantallas() {
    if (!mounted) {
      return;
    }

    for (final version in <StateProvider<int>>[
      solicitudesGuardiaVersionProvider,
      incidenciasVersionProvider,
      movimientosVersionProvider,
      usuariosVersionProvider,
      bicicleterosVersionProvider,
    ]) {
      ref.read(version.notifier).state = ref.read(version) + 1;
    }
  }

  void _alTocarPush() {
    final data = FcmServicio.instancia.notificacionTocada.value;
    if (data == null || !mounted) {
      return;
    }

    final sesion = ref.read(sesionProvider).value;
    final rol =
        sesion is SesionActiva ? sesion.usuario.rol : RolUsuario.estudiante;
    final tipo = data['tipo']?.toString();

    switch (tipo) {
      case 'SOLICITUD_GUARDIA':
        _abrirDestinoSolicitudGuardia(rol);
        break;
      case 'INCIDENCIA':
        _abrirDestinoIncidencia(rol);
        break;
      case 'MOVIMIENTO':
        _abrirDestinoMovimiento(rol);
        break;
    }

    FcmServicio.instancia.notificacionTocada.value = null;
    controladorNotificaciones.actualizar();
  }

  void _sincronizarTiempoRealConSesion(EstadoSesion? sesion) {
    final repositorio = ref.read(registroDispositivoPushProvider);

    if (sesion is SesionActiva) {
      tiempoRealService.conectar(sesion.token);
      FcmServicio.instancia.registrarToken(repositorio);
      return;
    }

    tiempoRealService.desconectar();
    FcmServicio.instancia.eliminarToken(repositorio);
  }

  Future<void> _abrirNotificaciones() async {
    final sesion = ref.read(sesionProvider).value;
    final rol =
        sesion is SesionActiva ? sesion.usuario.rol : RolUsuario.estudiante;

    final notificacion = await Navigator.of(context).push<NotificacionApp>(
      MaterialPageRoute(
        builder: (_) => const PantallaNotificaciones(),
      ),
    );

    if (mounted) {
      if (notificacion != null) {
        _navegarDesdeNotificacion(notificacion, rol);
      }
      await controladorNotificaciones.actualizar();
    }
  }

  void _navegarDesdeNotificacion(
    NotificacionApp notificacion,
    RolUsuario rol,
  ) {
    switch (notificacion.tipo) {
      case 'SOLICITUD_GUARDIA':
        _abrirDestinoSolicitudGuardia(rol);
        return;
      case 'INCIDENCIA':
        _abrirDestinoIncidencia(rol);
        return;
      case 'MOVIMIENTO':
        _abrirDestinoMovimiento(rol);
        return;
    }
  }

  void _abrirDestinoSolicitudGuardia(RolUsuario rol) {
    setState(() {
      tabSoporte = 0;
      if (rol == RolUsuario.guardia) {
        indice = 3;
      } else if (rol == RolUsuario.adminCentral) {
        indice = 3;
      } else if (rol == RolUsuario.administrador) {
        indice = 4;
      } else {
        indice = 3;
      }
      indicesVisitados.add(indice);
    });
    if (rol == RolUsuario.administrador) {
      abrirSeccionGestion(
        context,
        titulo: 'Atención',
        pantalla: const VistaSoporteAdministrador(initialIndex: 0),
      );
    }
  }

  void _abrirDestinoIncidencia(RolUsuario rol) {
    ref.read(filtrosIncidenciasProvider.notifier).state =
        const FiltrosIncidencias(estado: 'ABIERTAS');
    setState(() {
      tabSoporte = 1;
      if (rol == RolUsuario.administrador) {
        indice = 4;
      } else {
        indice = 3;
      }
      indicesVisitados.add(indice);
    });
    if (rol == RolUsuario.administrador) {
      abrirSeccionGestion(
        context,
        titulo: 'Atención',
        pantalla: const VistaSoporteAdministrador(initialIndex: 1),
      );
    }
  }

  void _abrirDestinoMovimiento(RolUsuario rol) {
    setState(() {
      if (rol == RolUsuario.guardia || rol == RolUsuario.adminCentral) {
        indice = 1;
      } else if (rol == RolUsuario.administrador) {
        indice = 4;
      } else {
        tabBicicletas = 1;
        navegacionesBicicletas++;
        indice = 1;
      }
      indicesVisitados.add(indice);
    });
    if (rol == RolUsuario.administrador) {
      abrirSeccionGestion(
        context,
        titulo: 'Movimientos',
        pantalla: const VistaMovimientosCentral(),
      );
    }
  }

  void _abrirHistorialPropio() {
    setState(() {
      tabBicicletas = 1;
      navegacionesBicicletas++;
      indice = 1;
      indicesVisitados.add(indice);
    });
  }

  void _abrirGestionAdmin(String titulo, Widget pantalla) {
    _seleccionarIndice(4);
    abrirSeccionGestion(context, titulo: titulo, pantalla: pantalla);
  }

  void _sincronizarNotificaciones() {
    if (!mounted) {
      return;
    }

    setState(() {});
    final nueva = controladorNotificaciones.nuevaNotificacion;
    if (nueva == null) {
      return;
    }

    controladorNotificaciones.marcarNuevaNotificacionMostrada();
    context.mostrarAvisoUnico(
      avisoNotificacion(nueva, onVer: _abrirNotificaciones),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sesionProvider, (_, siguiente) {
      _sincronizarTiempoRealConSesion(siguiente.value);
    });

    final sesion = ref.watch(sesionProvider).value;
    final rol =
        sesion is SesionActiva ? sesion.usuario.rol : RolUsuario.estudiante;
    final destinos = destinosPorRol(rol);
    final paginas = _paginasPorRol(rol);

    if (rolPaginas != rol) {
      final retomarIncidencia = ref.read(incidenciaPendienteAlIniciarProvider);
      rolPaginas = rol;
      indice = retomarIncidencia ? 3 : 0;
      if (retomarIncidencia) tabSoporte = 1;
      indicesVisitados = {0, indice};
    }
    if (indice >= paginas.length) {
      indice = 0;
      indicesVisitados = {0};
    }
    indicesVisitados.add(indice);

    final datos = titulosPorRol(rol);
    final datoActual = indice < datos.length ? datos[indice] : null;
    final paginasStack = [
      for (var i = 0; i < paginas.length; i++)
        indicesVisitados.contains(i)
            ? KeyedSubtree(
                key: ValueKey('${rol.name}-pagina-$i'),
                child: paginas[i],
              )
            : const SizedBox.shrink(),
    ];

    return Scaffold(
      backgroundColor: ColoresUbb.fondo,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(datoActual?.$2 ?? 'UBBike'),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: _abrirNotificaciones,
            icon: IconoNotificaciones(
              cantidad: controladorNotificaciones.noLeidas,
            ),
          ),
        ],
      ),
      body: ColoredBox(
        color: ColoresUbb.fondo,
        child: ContenedorResponsivo(
          anchoMaximo: indice == 0 ? double.infinity : 940,
          padding: indice == 0
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: IndexedStack(
            index: indice,
            sizing: StackFit.expand,
            children: paginasStack,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: indice,
        onDestinationSelected: _seleccionarIndice,
        destinations: destinos,
      ),
    );
  }

  List<Widget> _paginasPorRol(RolUsuario rol) {
    if (rol == RolUsuario.guardia) {
      return [
        VistaInicioGuardia(
          onOpenIngreso: _abrirIngresoGuardia,
        ),
        const VistaMovimientosCentral(),
        VistaIngresoGuardia(
          modoInicial: modoIngresoGuardia,
          onIrAHistorial: () => _seleccionarIndice(1),
        ),
        VistaSoporteGuardia(
          key: ValueKey('soporte-guardia-$tabSoporte'),
          initialIndex: tabSoporte,
        ),
        const VistaPerfil(rol: RolUsuario.guardia),
      ];
    }

    if (rol == RolUsuario.adminCentral) {
      return [
        VistaTableroCentral(
          onAbrirMovimientos: () => _seleccionarIndice(1),
          onAbrirGuardias: () => _seleccionarIndice(2),
          onAbrirSolicitudes: () =>
              _abrirDestinoSolicitudGuardia(RolUsuario.adminCentral),
          onAbrirIncidencias: () =>
              _abrirDestinoIncidencia(RolUsuario.adminCentral),
        ),
        const VistaMovimientosCentral(),
        const VistaGuardias(),
        VistaSoporteCentral(
          key: ValueKey('soporte-central-$tabSoporte'),
          initialIndex: tabSoporte,
        ),
        const VistaPerfil(rol: RolUsuario.adminCentral),
      ];
    }

    if (rol == RolUsuario.administrador) {
      return [
        VistaTableroAdministrador(
          onAbrirMovimientos: () =>
              _abrirDestinoMovimiento(RolUsuario.administrador),
          onAbrirGuardias: () => _abrirGestionAdmin(
            'Guardias',
            const VistaGuardias(),
          ),
          onAbrirSolicitudes: () =>
              _abrirDestinoSolicitudGuardia(RolUsuario.administrador),
          onAbrirIncidencias: () =>
              _abrirDestinoIncidencia(RolUsuario.administrador),
          onAbrirUsuarios: () => _abrirGestionAdmin(
            'Usuarios y permisos',
            const VistaGestionUsuarios(),
          ),
          onAbrirBicicleteros: () => _abrirGestionAdmin(
            'Bicicleteros',
            const VistaGestionBicicleteros(),
          ),
        ),
        VistaBicicletas(
          key: ValueKey(
            'bicicletas-admin-$tabBicicletas-$navegacionesBicicletas',
          ),
          initialIndex: tabBicicletas,
          vistaMovimientos: const VistaMovimientosUsuario(),
        ),
        VistaQrAdmin(onVerHistorial: _abrirHistorialPropio),
        VistaSoporteUsuario(
          key: ValueKey('soporte-admin-propio-$tabSoporte'),
          initialIndex: tabSoporte,
        ),
        const VistaMenuGestionAdmin(),
        const VistaPerfil(rol: RolUsuario.administrador),
      ];
    }

    return [
      const VistaInicioUsuario(),
      VistaBicicletas(
        key: ValueKey(
          'bicicletas-usuario-$tabBicicletas-$navegacionesBicicletas',
        ),
        initialIndex: tabBicicletas,
        vistaMovimientos: const VistaMovimientosUsuario(),
      ),
      VistaQrUsuario(onVerHistorial: _abrirHistorialPropio),
      VistaSoporteUsuario(
        key: ValueKey('soporte-usuario-$tabSoporte'),
        initialIndex: tabSoporte,
      ),
      VistaPerfil(rol: rol),
    ];
  }
}
