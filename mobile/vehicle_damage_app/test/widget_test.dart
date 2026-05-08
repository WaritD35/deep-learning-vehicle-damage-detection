import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vehicle_damage_app/main.dart';

void main() {
  testWidgets('Vehicle damage app renders home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const VehicleDamageApp());
    await tester.pump();

    expect(find.text('Damage reports'), findsOneWidget);
  });
}
