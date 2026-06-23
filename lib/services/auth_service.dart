import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const _storage = FlutterSecureStorage();

  static const String _docenteIdKey = 'docente_id';
  static const String _usuarioKey = 'usuario';

  static const String _loginUrl = 'https://DOMINIO.com/api/login';

  static Future<bool> tieneSesionActiva() async {
    final docenteId = await obtenerDocenteId();
    return docenteId != null && docenteId.isNotEmpty && docenteId != '0';
  }

  static Future<String?> obtenerDocenteId() async {
    return _storage.read(key: _docenteIdKey);
  }

  static Future<int> obtenerDocenteIdInt() async {
    final id = await obtenerDocenteId();
    return int.tryParse(id ?? '0') ?? 0;
  }

  static Future<String?> obtenerUsuario() async {
    return _storage.read(key: _usuarioKey);
  }

  static Future<void> guardarSesion({
    required int docenteId,
    required String usuario,
  }) async {
    await _storage.write(key: _docenteIdKey, value: docenteId.toString());
    await _storage.write(key: _usuarioKey, value: usuario);
  }

  static Future<void> cerrarSesion() async {
    await _storage.delete(key: _docenteIdKey);
    await _storage.delete(key: _usuarioKey);
  }

  static Future<LoginResult> login({
    required String usuario,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    if (usuario.trim().isEmpty || password.isEmpty) {
      return LoginResult.error('Ingresa usuario y contraseña');
    }

    // Temporal mientras no existe el servidor:
    // usamos 1 como id fijo de docente de prueba.
    await guardarSesion(
      docenteId: 1,
      usuario: usuario.trim(),
    );

    return LoginResult.ok();

    /*
    // Versión para cuando el servidor esté listo.
    try {
      final response = await http
          .post(
            Uri.parse(_loginUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'usuario': usuario.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return LoginResult.error('No fue posible iniciar sesión.');
      }

      final docenteId = int.tryParse(response.body.trim());

      if (docenteId == null) {
        return LoginResult.error('Respuesta inválida del servidor.');
      }

      if (docenteId == -1) {
        return LoginResult.error('Usuario o contraseña incorrectos.');
      }

      if (docenteId <= 0) {
        return LoginResult.error('El servidor devolvió un docente inválido.');
      }

      await guardarSesion(
        docenteId: docenteId,
        usuario: usuario.trim(),
      );

      return LoginResult.ok();
    } catch (_) {
      return LoginResult.error('No fue posible conectar con el servidor.');
    }
    */
  }
}

class LoginResult {
  final bool success;
  final String? message;

  const LoginResult._({
    required this.success,
    this.message,
  });

  factory LoginResult.ok() {
    return const LoginResult._(success: true);
  }

  factory LoginResult.error(String message) {
    return LoginResult._(
      success: false,
      message: message,
    );
  }
}