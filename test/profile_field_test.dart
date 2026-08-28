import 'package:cbi_app/src/ui/widgets/profile_field.dart';
import 'package:cbi_app/src/ui/widgets/shadow_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('shows the value when one is set', (tester) async {
    await tester.pumpWidget(
      _host(
        const ProfileField(
          icon: Icons.work_outline_rounded,
          label: 'Position',
          value: 'Field Engineer',
        ),
      ),
    );

    expect(find.text('Position'), findsOneWidget);
    expect(find.text('Field Engineer'), findsOneWidget);
    expect(find.text('غير محدد'), findsNothing);
  });

  testWidgets('falls back to a placeholder when the value is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProfileField(
          icon: Icons.work_outline_rounded,
          label: 'Position',
          value: null,
        ),
      ),
    );

    expect(find.text('غير محدد'), findsOneWidget);
  });

  testWidgets('renders an empty string as a placeholder, not a blank row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProfileField(
          icon: Icons.badge_outlined,
          label: 'Title',
          value: '',
        ),
      ),
    );

    expect(find.text('غير محدد'), findsOneWidget);
  });

  testWidgets('avatar falls back to a silhouette without a photo or name', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ShadowAvatar()));

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('avatar prefers initials over the silhouette', (tester) async {
    await tester.pumpWidget(_host(const ShadowAvatar(initials: 'AH')));

    expect(find.text('AH'), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
  });
}
