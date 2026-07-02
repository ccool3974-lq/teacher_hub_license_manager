import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_hub_license_manager/app/app.dart';

void main() {
  testWidgets('license manager app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const LicenseManagerApp());
    await tester.pumpAndSettle();

    expect(find.text('授权运营工作台'), findsOneWidget);
    expect(find.byTooltip('私钥设置'), findsOneWidget);
  });
}
