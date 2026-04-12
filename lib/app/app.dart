import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:teacher_hub_license_manager/app/router.dart';

class LicenseManagerApp extends StatelessWidget {
  const LicenseManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Teacher Hub License Manager',
      routerConfig: AppRouter.createRouter(),
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C6B61)),
        useMaterial3: true,
      ),
    );
  }
}
