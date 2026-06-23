import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'home_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool cargando = true;
  bool autenticado = false;

  @override
  void initState() {
    super.initState();
    verificarSesion();
  }

  Future<void> verificarSesion() async {
    final tieneSesion = await AuthService.tieneSesionActiva();

    if (!mounted) return;

    setState(() {
      autenticado = tieneSesion;
      cargando = false;
    });
  }

  void marcarAutenticado() {
    setState(() {
      autenticado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!autenticado) {
      return LoginPage(
        onLoginCorrecto: marcarAutenticado,
      );
    }

    return const HomePage();
  }
}