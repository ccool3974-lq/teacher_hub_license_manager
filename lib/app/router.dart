import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_hub_license_manager/app/private_key_settings_page.dart';
import 'package:teacher_hub_license_manager/modules/license_record/presentation/license_dashboard_page.dart';
import 'package:teacher_hub_license_manager/modules/license_record/presentation/license_detail_page.dart';
import 'package:teacher_hub_license_manager/modules/license_record/presentation/license_form_page.dart';
import 'package:teacher_hub_license_manager/modules/license_record/presentation/license_list_page.dart';
import 'package:teacher_hub_license_manager/shared/navigation/app_route_observer.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter createRouter() {
    return GoRouter(
      observers: <NavigatorObserver>[appRouteObserver],
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const LicenseDashboardPage(),
        ),
        GoRoute(
          path: '/records',
          builder: (context, state) => const LicenseListPage(),
        ),
        GoRoute(
          path: '/new',
          builder: (context, state) => const LicenseFormPage(),
        ),
        GoRoute(
          path: '/private-key',
          builder: (context, state) => const PrivateKeySettingsPage(),
        ),
        GoRoute(
          path: '/records/:licenseId',
          builder: (context, state) => LicenseDetailPage(
            licenseId: state.pathParameters['licenseId'] ?? '',
          ),
        ),
      ],
    );
  }
}
