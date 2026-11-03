import 'package:flutter/material.dart';

import 'api/finance_api.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

class FinanceFlowApp extends StatelessWidget {
  const FinanceFlowApp({super.key, required this.api});
  final FinanceApi api;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FinanceFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF126B52), brightness: Brightness.light),
          scaffoldBackgroundColor: const Color(0xFFF5F7F5),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF5F7F5), surfaceTintColor: Colors.transparent),
          cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE7ECE8)))),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF7F9F7),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE1E8E2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE1E8E2))),
          ),
        ),
        home: _SessionGate(api: api),
      );
}

class _SessionGate extends StatefulWidget {
  const _SessionGate({required this.api});
  final FinanceApi api;
  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late Future<bool> _session = widget.api.hasSession;
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _session,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return snapshot.data!
              ? HomeScreen(api: widget.api, onLogout: _loggedOut)
              : AuthScreen(api: widget.api, onSignedIn: _signedIn);
        },
      );

  void _signedIn() => setState(() => _session = Future.value(true));
  void _loggedOut() => setState(() => _session = Future.value(false));
}
