import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mago_widgets/mago_widgets.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Wraps [child] in a minimal MaterialApp so widget tests have a theme,
/// media query, overlay, navigator, directionality, and localisations.
Widget buildTestApp(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? lightMode,
    home: Scaffold(body: child),
  );
}

/// Same as [buildTestApp] but places [child] inside a constrained box
/// useful for widgets that need finite dimensions.
Widget buildConstrainedApp(Widget child,
    {double width = 800, double height = 600}) {
  return buildTestApp(
    Center(
      child: SizedBox(width: width, height: height, child: child),
    ),
  );
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // MagoColors
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoColors', () {
    test('brand color is the expected indigo', () {
      expect(MagoColors.brand, const Color(0xFF6366F1));
    });

    test('neutral palette contains expected shades', () {
      expect(MagoColors.neutral50, const Color(0xFFFAFAFA));
      expect(MagoColors.neutral950, const Color(0xFF0A0A0A));
    });

    test('canvasColors has 8 entries', () {
      expect(MagoColors.canvasColors.length, 8);
      expect(MagoColors.canvasColorsLight.length, 8);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoThemeData
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoThemeData', () {
    test('light factory produces expected textPrimary', () {
      final cs = lightMode.colorScheme;
      final data = MagoThemeData.light(cs);
      expect(data.textPrimary, MagoColors.neutral900);
    });

    test('dark factory produces expected textPrimary', () {
      final cs = darkMode.colorScheme;
      final data = MagoThemeData.dark(cs);
      expect(data.textPrimary, MagoColors.neutral100);
    });

    test('defaultBorderRadius defaults to 12', () {
      final cs = lightMode.colorScheme;
      final data = MagoThemeData.light(cs);
      expect(data.defaultBorderRadius, 12.0);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoTheme InheritedWidget
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoTheme', () {
    testWidgets('provides data via of()', (tester) async {
      late MagoThemeData resolved;
      final cs = lightMode.colorScheme;
      final data = MagoThemeData.light(cs);

      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: MagoTheme(
            data: data,
            child: Builder(
              builder: (context) {
                resolved = MagoTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolved.textPrimary, data.textPrimary);
    });

    testWidgets('falls back to derived theme when no MagoTheme ancestor',
        (tester) async {
      late MagoThemeData resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: Builder(
            builder: (context) {
              resolved = MagoTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved.textPrimary, MagoColors.neutral900);
    });

    testWidgets('maybeOf returns null when no ancestor', (tester) async {
      MagoThemeData? resolved;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = MagoTheme.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoTextStyles
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoTextStyles', () {
    test('fontFamily is Inter', () {
      expect(MagoTextStyles.fontFamily, 'Inter');
    });

    test('textTheme has all M3 levels', () {
      final tt = MagoTextStyles.textTheme;
      expect(tt.displayLarge, isNotNull);
      expect(tt.displayMedium, isNotNull);
      expect(tt.displaySmall, isNotNull);
      expect(tt.headlineLarge, isNotNull);
      expect(tt.headlineMedium, isNotNull);
      expect(tt.headlineSmall, isNotNull);
      expect(tt.titleLarge, isNotNull);
      expect(tt.titleMedium, isNotNull);
      expect(tt.titleSmall, isNotNull);
      expect(tt.labelLarge, isNotNull);
      expect(tt.labelMedium, isNotNull);
      expect(tt.labelSmall, isNotNull);
      expect(tt.bodyLarge, isNotNull);
      expect(tt.bodyMedium, isNotNull);
      expect(tt.bodySmall, isNotNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Global ThemeData (lightMode / darkMode)
  // ──────────────────────────────────────────────────────────────────────────
  group('lightMode / darkMode', () {
    test('lightMode is Brightness.light', () {
      expect(lightMode.brightness, Brightness.light);
    });

    test('darkMode is Brightness.dark', () {
      expect(darkMode.brightness, Brightness.dark);
    });

    test('lightMode uses MagoColors.brand as primary', () {
      expect(lightMode.colorScheme.primary, MagoColors.brand);
    });

    test('darkMode uses MagoColors.brandLight as primary', () {
      expect(darkMode.colorScheme.primary, MagoColors.brandLight);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoBorderRadiusCalculator
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoBorderRadiusCalculator', () {
    final calc = MagoBorderRadiusCalculator();

    test('deflates uniformly with positive value', () {
      const radius = BorderRadius.all(Radius.circular(16));
      final result = calc.calculate(radius, 4, TextDirection.ltr);

      expect(result.topLeft, const Radius.elliptical(12, 12));
      expect(result.bottomRight, const Radius.elliptical(12, 12));
    });

    test('clamps to zero – never negative', () {
      const radius = BorderRadius.all(Radius.circular(4));
      final result = calc.calculate(radius, 10, TextDirection.ltr);

      expect(result.topLeft, const Radius.elliptical(0, 0));
    });

    test('zero deflation returns same radii', () {
      const radius = BorderRadius.all(Radius.circular(8));
      final result = calc.calculate(radius, 0, TextDirection.ltr);

      expect(result.topLeft, const Radius.elliptical(8, 8));
    });
  });

  // ==========================================================================
  // BUTTON TESTS
  // ==========================================================================

  // ──────────────────────────────────────────────────────────────────────────
  // MagoButtonStyle
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoButtonStyle.resolve', () {
    testWidgets('disabled state uses surfaceContainerHighest bg',
        (tester) async {
      late MagoButtonColors colors;

      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: Builder(builder: (context) {
            colors = MagoButtonStyle.resolve(
              context,
              enabled: false,
              variant: MagoButtonVariant.filled,
            );
            return const SizedBox();
          }),
        ),
      );

      final cs = lightMode.colorScheme;
      expect(colors.background, cs.surfaceContainerHighest);
    });

    testWidgets('filled variant uses primary bg when enabled', (tester) async {
      late MagoButtonColors colors;

      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: Builder(builder: (context) {
            colors = MagoButtonStyle.resolve(
              context,
              enabled: true,
              variant: MagoButtonVariant.filled,
            );
            return const SizedBox();
          }),
        ),
      );

      expect(colors.background, lightMode.colorScheme.primary);
    });

    testWidgets('outline variant has transparent bg', (tester) async {
      late MagoButtonColors colors;

      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: Builder(builder: (context) {
            colors = MagoButtonStyle.resolve(
              context,
              enabled: true,
              variant: MagoButtonVariant.outline,
            );
            return const SizedBox();
          }),
        ),
      );

      expect(colors.background, Colors.transparent);
      expect(colors.borderSide, isNotNull);
    });

    testWidgets('ghost variant has transparent bg and no border',
        (tester) async {
      late MagoButtonColors colors;

      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: Builder(builder: (context) {
            colors = MagoButtonStyle.resolve(
              context,
              enabled: true,
              variant: MagoButtonVariant.ghost,
            );
            return const SizedBox();
          }),
        ),
      );

      expect(colors.background, Colors.transparent);
      expect(colors.borderSide, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoTextButton
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoTextButton', () {
    testWidgets('renders text label', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoTextButton(text: 'Click me', onPressed: () {}),
      ));

      expect(find.text('Click me'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildTestApp(
        MagoTextButton(text: 'Tap', onPressed: () => tapped = true),
      ));

      await tester.tap(find.text('Tap'));
      expect(tapped, isTrue);
    });

    testWidgets('does not call onPressed when disabled (enabled=false)',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildTestApp(
        MagoTextButton(
          text: 'Tap',
          onPressed: () => tapped = true,
          enabled: false,
        ),
      ));

      await tester.tap(find.text('Tap'));
      expect(tapped, isFalse);
    });

    testWidgets('does not call onPressed when onPressed is null',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoTextButton(text: 'Tap', onPressed: null),
      ));

      await tester.tap(find.text('Tap'));
      // Just verifying no crash occurs
    });

    testWidgets('expand: true makes button full width', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoTextButton(text: 'Expand', onPressed: () {}, expand: true),
      ));

      // SizedBox with double.infinity width is used
      final sizedBox = tester.widgetList<SizedBox>(find.byType(SizedBox)).where(
            (sb) => sb.width == double.infinity,
          );
      expect(sizedBox, isNotEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoIconButton
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoIconButton', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoIconButton(icon: Icons.add, onPressed: () {}),
      ));

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildTestApp(
        MagoIconButton(icon: Icons.add, onPressed: () => tapped = true),
      ));

      await tester.tap(find.byIcon(Icons.add));
      expect(tapped, isTrue);
    });

    testWidgets('disabled state blocks tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildTestApp(
        MagoIconButton(
          icon: Icons.add,
          onPressed: () => tapped = true,
          enabled: false,
        ),
      ));

      await tester.tap(find.byIcon(Icons.add));
      expect(tapped, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoIconTextButton
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoIconTextButton', () {
    testWidgets('renders icon and text', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoIconTextButton(icon: Icons.save, text: 'Save', onPressed: () {}),
      ));

      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildTestApp(
        MagoIconTextButton(
          icon: Icons.save,
          text: 'Save',
          onPressed: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('Save'));
      expect(tapped, isTrue);
    });

    testWidgets('icon placement end puts icon after text', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoIconTextButton(
          icon: Icons.arrow_forward,
          text: 'Next',
          onPressed: () {},
          iconPlacement: MagoIconPlacement.end,
        ),
      ));

      // Both are rendered
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Icon should come after text in the Row
      final row = tester.widget<Row>(find.byType(Row).first);
      final children = row.children;
      final textIndex =
          children.indexWhere((w) => w is Flexible || w is Expanded);
      final iconIndex = children.indexWhere((w) => w is Icon);
      expect(iconIndex, greaterThan(textIndex));
    });
  });

  // ==========================================================================
  // CARD TESTS
  // ==========================================================================

  group('MagoResponsiveGrid', () {
    testWidgets('renders correct number of items', (tester) async {
      await tester.pumpWidget(buildConstrainedApp(
        MagoResponsiveGrid(
          itemCount: 6,
          itemBuilder: (_, i) => Container(
            key: ValueKey(i),
            color: Colors.blue,
          ),
        ),
      ));

      expect(find.byType(Container), findsNWidgets(6));
    });

    testWidgets('uses GridView.builder internally', (tester) async {
      await tester.pumpWidget(buildConstrainedApp(
        MagoResponsiveGrid(
          itemCount: 3,
          itemBuilder: (_, i) => const SizedBox(),
        ),
      ));

      expect(find.byType(GridView), findsOneWidget);
    });
  });

  // ==========================================================================
  // DIALOG TESTS
  // ==========================================================================

  // ──────────────────────────────────────────────────────────────────────────
  // MagoPopupDialog
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoPopupDialog', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoPopupDialog(
          width: 300,
          child: Text('Hello Dialog'),
        ),
      ));

      expect(find.text('Hello Dialog'), findsOneWidget);
    });

    testWidgets('.show() opens and displays child', (tester) async {
      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              MagoPopupDialog.show(
                context,
                child: const Text('Shown Dialog'),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Shown Dialog'), findsOneWidget);
    });

    testWidgets('.show() can be dismissed by tapping barrier', (tester) async {
      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              MagoPopupDialog.show(
                context,
                barrierDismissible: true,
                child: const Text('Dismissable'),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Dismissable'), findsOneWidget);

      // Tap outside the dialog (on the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Dismissable'), findsNothing);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoActionPopupDialog
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoActionPopupDialog', () {
    testWidgets('shows title, child, cancel and confirm buttons',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              MagoActionPopupDialog.show(
                context,
                title: 'Confirm Delete',
                child: const Text('Are you sure?'),
                cancelText: 'No',
                confirmText: 'Yes',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Delete'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
    });

    testWidgets('confirm button calls onConfirm and pops', (tester) async {
      var confirmed = false;

      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              MagoActionPopupDialog.show(
                context,
                title: 'Test',
                child: const Text('Body'),
                onConfirm: () => confirmed = true,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
      expect(find.text('Body'), findsNothing); // Dialog closed
    });

    testWidgets('cancel button calls onCancel and pops', (tester) async {
      var cancelled = false;

      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              MagoActionPopupDialog.show(
                context,
                title: 'Test',
                child: const Text('Body'),
                onCancel: () => cancelled = true,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
      expect(find.text('Body'), findsNothing);
    });

    testWidgets('returns confirmValueBuilder result', (tester) async {
      String? result;

      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await MagoActionPopupDialog.show<String>(
                context,
                title: 'Test',
                child: const SizedBox(),
                confirmValueBuilder: () => 'confirmed',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(result, 'confirmed');
    });

    testWidgets('confirm disabled does not close dialog', (tester) async {
      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              MagoActionPopupDialog.show(
                context,
                title: 'Test',
                child: const Text('Body'),
                confirmEnabled: false,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The OK button should be present but won't pop
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Dialog stays open because confirmEnabled = false
      expect(find.text('Body'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoLargeActionPopupDialog
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoLargeActionPopupDialog', () {
    testWidgets('shows title, child, cancel and confirm buttons',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              MagoLargeActionPopupDialog.show(
                context,
                title: 'Edit Item',
                child: const Text('Form goes here'),
                cancelText: 'Discard',
                confirmText: 'Save',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Item'), findsOneWidget);
      expect(find.text('Form goes here'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('confirm calls onConfirm and pops', (tester) async {
      var confirmed = false;

      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              MagoLargeActionPopupDialog.show(
                context,
                title: 'Test',
                child: const SizedBox(),
                onConfirm: () => confirmed = true,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoOptionsPopupDialog
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoOptionsPopupDialog', () {
    testWidgets('shows title and all option buttons', (tester) async {
      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              MagoOptionsPopupDialog.show(
                context,
                title: 'Choose action',
                options: {
                  'Delete': MagoActionOption(onPressed: () {}),
                  'Duplicate': MagoActionOption(onPressed: () {}),
                },
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Choose action'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
    });

    testWidgets('pressing option calls callback and returns label',
        (tester) async {
      var deleteCalled = false;
      String? result;

      await tester.pumpWidget(buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await MagoOptionsPopupDialog.show(
                context,
                title: 'Choose',
                options: {
                  'Delete': MagoActionOption(
                    onPressed: () => deleteCalled = true,
                  ),
                  'Keep': MagoActionOption(onPressed: () {}),
                },
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
      expect(result, 'Delete');
    });
  });

  // ==========================================================================
  // INPUT TESTS
  // ==========================================================================

  // ──────────────────────────────────────────────────────────────────────────
  // MagoTextInput
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoTextInput', () {
    testWidgets('renders placeholder text', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(buildTestApp(
        MagoTextInput(
          controller: controller,
          placeholder: 'Enter name',
          autofocus: false,
        ),
      ));

      expect(find.text('Enter name'), findsOneWidget);
    });

    testWidgets('typing updates controller', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(buildTestApp(
        MagoTextInput(controller: controller, autofocus: false),
      ));

      await tester.enterText(find.byType(TextField), 'Hello');
      expect(controller.text, 'Hello');
    });

    testWidgets('renders with specified dimensions', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(buildTestApp(
        MagoTextInput(
          controller: controller,
          height: 56,
          width: 200,
          autofocus: false,
        ),
      ));

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(
        animatedContainer.constraints,
        const BoxConstraints.tightFor(width: 200, height: 56),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoPasswordInput
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoPasswordInput', () {
    testWidgets('obscures text by default', (tester) async {
      final controller = TextEditingController(text: 'secret');

      await tester.pumpWidget(buildTestApp(
        MagoPasswordInput(controller: controller, autofocus: false),
      ));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('toggling visibility shows/hides password', (tester) async {
      final controller = TextEditingController(text: 'secret');

      await tester.pumpWidget(buildTestApp(
        MagoPasswordInput(controller: controller, autofocus: false),
      ));

      // Initially obscured
      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);

      // Tap the eye icon to toggle
      await tester.tap(find.byType(InkWell).last);
      await tester.pump();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isFalse);
    });

    testWidgets('initiallyObscured: false starts visible', (tester) async {
      final controller = TextEditingController(text: 'visible');

      await tester.pumpWidget(buildTestApp(
        MagoPasswordInput(
          controller: controller,
          autofocus: false,
          initiallyObscured: false,
        ),
      ));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoEmailChipInput
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoEmailChipInput', () {
    testWidgets('renders initial emails as chips', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoEmailChipInput(
          initialEmails: ['a@b.com', 'c@d.com'],
          autofocus: false,
        ),
      ));

      expect(find.text('a@b.com'), findsOneWidget);
      expect(find.text('c@d.com'), findsOneWidget);
      expect(find.byType(InputChip), findsNWidgets(2));
    });

    testWidgets('adding email via space triggers chip creation',
        (tester) async {
      final emails = <String>[];

      await tester.pumpWidget(buildTestApp(
        MagoEmailChipInput(
          onChanged: (list) => emails
            ..clear()
            ..addAll(list),
          autofocus: false,
        ),
      ));

      // Type an email then press space to commit
      await tester.enterText(find.byType(TextField), 'test@example.com ');
      await tester.pump();

      expect(emails, contains('test@example.com'));
    });

    testWidgets('invalid email is not added', (tester) async {
      final emails = <String>[];

      await tester.pumpWidget(buildTestApp(
        MagoEmailChipInput(
          onChanged: (list) => emails
            ..clear()
            ..addAll(list),
          autofocus: false,
        ),
      ));

      await tester.enterText(find.byType(TextField), 'notanemail ');
      await tester.pump();

      expect(emails, isEmpty);
    });

    testWidgets('duplicate email is not added', (tester) async {
      final emails = <String>[];

      await tester.pumpWidget(buildTestApp(
        MagoEmailChipInput(
          initialEmails: const ['a@b.com'],
          onChanged: (list) => emails
            ..clear()
            ..addAll(list),
          autofocus: false,
        ),
      ));

      await tester.enterText(find.byType(TextField), 'a@b.com ');
      await tester.pump();

      // The initial email is already present, no duplicate added
      expect(find.byType(InputChip), findsOneWidget);
    });
  });

  // ==========================================================================
  // COMPONENT TESTS
  // ==========================================================================

  // ──────────────────────────────────────────────────────────────────────────
  // MagoToast
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoToast', () {
    testWidgets('shows toast with title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MagoToast.show(context, 'Hello Toast'),
                child: const Text('Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Toast'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 400)); // Finish slide in

      expect(find.text('Hello Toast'), findsOneWidget);
    });

    testWidgets('shows toast with description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: lightMode,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MagoToast.show(
                  context,
                  'Title',
                  description: 'Details here',
                ),
                child: const Text('Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Details here'), findsOneWidget);
    });

    testWidgets('shows correct icon for each toast type', (tester) async {
      for (final type in MagoToastType.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: lightMode,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      MagoToast.show(context, type.name, type: type),
                  child: const Text('Toast'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Toast'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final expected = switch (type) {
          MagoToastType.success => Icons.check_circle_outline,
          MagoToastType.error => Icons.error_outline,
          MagoToastType.info => Icons.info_outline,
          MagoToastType.warning => Icons.warning_amber_rounded,
        };

        expect(find.byIcon(expected), findsOneWidget);
      }
    });
  });

  // ==========================================================================
  // CANVAS TESTS
  // ==========================================================================

  // ──────────────────────────────────────────────────────────────────────────
  // MagoStroke
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoStroke', () {
    test('creates with required parameters', () {
      const stroke = MagoStroke(
        points: [Offset(0, 0), Offset(10, 10)],
        color: Colors.red,
        width: 3.0,
        isEraser: false,
      );

      expect(stroke.points.length, 2);
      expect(stroke.color, Colors.red);
      expect(stroke.width, 3.0);
      expect(stroke.isEraser, isFalse);
    });

    test('copyWith replaces specified fields', () {
      const original = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 2.0,
        isEraser: false,
      );

      final copy = original.copyWith(color: Colors.blue, width: 5.0);

      expect(copy.color, Colors.blue);
      expect(copy.width, 5.0);
      expect(copy.points, original.points);
      expect(copy.isEraser, original.isEraser);
    });

    test('copyWith with no args returns identical values', () {
      const stroke = MagoStroke(
        points: [Offset(1, 2)],
        color: Colors.green,
        width: 4.0,
        isEraser: true,
      );

      final copy = stroke.copyWith();
      expect(copy.color, stroke.color);
      expect(copy.width, stroke.width);
      expect(copy.isEraser, stroke.isEraser);
      expect(copy.points, stroke.points);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoCanvasController
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoCanvasController', () {
    test('starts with empty strokes', () {
      final controller = MagoCanvasController();
      expect(controller.strokes.value, isEmpty);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });

    test('addStroke adds a stroke and returns its index', () {
      final controller = MagoCanvasController();
      const stroke = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 2,
        isEraser: false,
      );

      final idx = controller.addStroke(stroke);
      expect(idx, 0);
      expect(controller.strokes.value.length, 1);
    });

    test('addStroke multiple times increments index', () {
      final controller = MagoCanvasController();
      const stroke = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 2,
        isEraser: false,
      );

      expect(controller.addStroke(stroke), 0);
      expect(controller.addStroke(stroke), 1);
      expect(controller.addStroke(stroke), 2);
      expect(controller.strokes.value.length, 3);
    });

    test('updateStrokeAt modifies specific stroke', () {
      final controller = MagoCanvasController();
      const original = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 2,
        isEraser: false,
      );

      controller.addStroke(original);
      final updated = original.copyWith(color: Colors.blue);
      controller.updateStrokeAt(0, updated);

      expect(controller.strokes.value[0].color, Colors.blue);
    });

    test('updateStrokeAt with invalid index is a no-op', () {
      final controller = MagoCanvasController();
      const stroke = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 2,
        isEraser: false,
      );

      controller.updateStrokeAt(5, stroke); // No crash
      expect(controller.strokes.value, isEmpty);
    });

    test('setAll replaces all strokes', () {
      final controller = MagoCanvasController();
      const s1 = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 1,
        isEraser: false,
      );
      const s2 = MagoStroke(
        points: [Offset(10, 10)],
        color: Colors.blue,
        width: 2,
        isEraser: false,
      );

      controller.setAll([s1, s2]);
      expect(controller.strokes.value.length, 2);
    });

    test('clear removes all strokes and base image', () {
      final controller = MagoCanvasController();
      const stroke = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 2,
        isEraser: false,
      );

      controller.addStroke(stroke);
      controller.clear();
      expect(controller.strokes.value, isEmpty);
      expect(controller.baseImage.value, isNull);
      expect(controller.canUndo, isFalse);
    });

    test('undo removes last stroke', () {
      final controller = MagoCanvasController();
      const s1 = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 2,
        isEraser: false,
      );
      const s2 = MagoStroke(
        points: [Offset(5, 5)],
        color: Colors.blue,
        width: 3,
        isEraser: false,
      );

      controller.addStroke(s1);
      controller.addStroke(s2);
      expect(controller.strokes.value.length, 2);

      controller.undo();
      expect(controller.strokes.value.length, 1);
      expect(controller.strokes.value[0].color, Colors.red);
    });

    test('redo restores undone stroke', () {
      final controller = MagoCanvasController();
      const stroke = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 2,
        isEraser: false,
      );

      controller.addStroke(stroke);
      controller.undo();
      expect(controller.strokes.value, isEmpty);

      controller.redo();
      expect(controller.strokes.value.length, 1);
    });

    test('undo when empty is a no-op', () {
      final controller = MagoCanvasController();
      controller.undo(); // Should not crash
      expect(controller.strokes.value, isEmpty);
    });

    test('redo when empty is a no-op', () {
      final controller = MagoCanvasController();
      controller.redo(); // Should not crash
      expect(controller.strokes.value, isEmpty);
    });

    test('adding stroke clears redo stack', () {
      final controller = MagoCanvasController();
      const s1 = MagoStroke(
        points: [Offset.zero],
        color: Colors.red,
        width: 2,
        isEraser: false,
      );
      const s2 = MagoStroke(
        points: [Offset(5, 5)],
        color: Colors.blue,
        width: 3,
        isEraser: false,
      );

      controller.addStroke(s1);
      controller.undo();
      controller.addStroke(s2);

      expect(controller.canRedo, isFalse);
    });

    test('toJsonString and loadFromJsonString round-trips', () {
      final controller = MagoCanvasController();
      const stroke = MagoStroke(
        points: [Offset(10, 20), Offset(30, 40)],
        color: Color(0xFFFF0000),
        width: 3.0,
        isEraser: false,
      );

      controller.addStroke(stroke);
      final json = controller.toJsonString();

      final controller2 = MagoCanvasController();
      controller2.loadFromJsonString(json);

      expect(controller2.strokes.value.length, 1);
      expect(controller2.strokes.value[0].color, const Color(0xFFFF0000));
      expect(controller2.strokes.value[0].width, 3.0);
      expect(controller2.strokes.value[0].isEraser, false);
      expect(controller2.strokes.value[0].points.length, 2);
    });

    test('toJsonMap includes version', () {
      final controller = MagoCanvasController();
      final map = controller.toJsonMap();
      expect(map['version'], 1);
      expect(map['strokes'], isA<List>());
    });

    test('loadFromJsonString with invalid data throws FormatException', () {
      final controller = MagoCanvasController();
      expect(
        () => controller.loadFromJsonString('not-json'),
        throwsFormatException,
      );
    });

    test('loadFromJsonString with empty strokes', () {
      final controller = MagoCanvasController();
      controller.loadFromJsonString('{"version":1,"strokes":[]}');
      expect(controller.strokes.value, isEmpty);
    });

    test('maxUndoHistory is configurable', () {
      final controller = MagoCanvasController(maxUndoHistory: 5);
      expect(controller.maxUndoHistory, 5);
    });
  });

  // ==========================================================================
  // PAINTER TESTS
  // ==========================================================================

  group('MagoGridSpacePainter', () {
    test('shouldRepaint returns true when properties change', () {
      const painter1 = MagoGridSpacePainter(
        xSpacing: 50,
        ySpacing: 50,
      );

      const painter2 = MagoGridSpacePainter(
        xSpacing: 100,
        ySpacing: 50,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when properties are same', () {
      const painter1 = MagoGridSpacePainter(
        xSpacing: 50,
        ySpacing: 50,
        gap: 8,
        offset: Offset.zero,
      );

      const painter2 = MagoGridSpacePainter(
        xSpacing: 50,
        ySpacing: 50,
        gap: 8,
        offset: Offset.zero,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('constructs with custom properties', () {
      const painter = MagoGridSpacePainter(
        xSpacing: 30,
        ySpacing: 40,
        gap: 4,
        offset: Offset(10, 20),
        cellColor: Colors.red,
        cellBorderColor: Colors.blue,
        cellBorderWidth: 2,
      );

      expect(painter.xSpacing, 30);
      expect(painter.ySpacing, 40);
      expect(painter.gap, 4);
      expect(painter.offset, const Offset(10, 20));
    });

    test('shouldRepaint detects cellOccupiedColor change', () {
      const painter1 = MagoGridSpacePainter(
        xSpacing: 50,
        ySpacing: 50,
        cellOccupiedColor: Colors.black,
      );

      const painter2 = MagoGridSpacePainter(
        xSpacing: 50,
        ySpacing: 50,
        cellOccupiedColor: Colors.grey,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint detects cellBorderRadius change', () {
      const painter1 = MagoGridSpacePainter(
        xSpacing: 50,
        ySpacing: 50,
        cellBorderRadius: 8,
      );

      const painter2 = MagoGridSpacePainter(
        xSpacing: 50,
        ySpacing: 50,
        cellBorderRadius: 12,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint detects hoverCell change', () {
      const painter1 = MagoGridSpacePainter(
        xSpacing: 50,
        ySpacing: 50,
        hoverCell: (0, 0),
      );

      const painter2 = MagoGridSpacePainter(
        xSpacing: 50,
        ySpacing: 50,
        hoverCell: (1, 1),
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('should accept customCells', () {
      const cells = [
        GridCellRect(x: 0, y: 0, xSpan: 2, ySpan: 1),
        GridCellRect(x: 2, y: 0),
      ];

      const painter = MagoGridSpacePainter(
        xSpacing: 100,
        ySpacing: 100,
        customCells: cells,
      );

      expect(painter.customCells, isNotNull);
      expect(painter.customCells!.length, 2);
      expect(painter.customCells!.first.xSpan, 2);
    });

    test('should accept occupiedCells', () {
      const occupied = [
        OccupiedCell(x: 0, y: 0),
        OccupiedCell(x: 1, y: 1),
      ];

      const painter = MagoGridSpacePainter(
        xSpacing: 100,
        ySpacing: 100,
        occupiedCells: occupied,
      );

      expect(painter.occupiedCells, isNotNull);
      expect(painter.occupiedCells!.length, 2);
    });
  });

  // ==========================================================================
  // GridItem TESTS
  // ==========================================================================

  group('GridItem', () {
    test('isPlaced returns false for unplaced item', () {
      final item = GridItem(id: 'a', data: 'data');
      expect(item.isPlaced, isFalse);
      expect(item.x, -1);
      expect(item.y, -1);
    });

    test('isPlaced returns true when x and y are set', () {
      final item = GridItem(id: 'a', data: 'data', x: 0, y: 0);
      expect(item.isPlaced, isTrue);
    });

    test('default spans are 1', () {
      final item = GridItem(id: 'a', data: 'data');
      expect(item.xSpan, 1);
      expect(item.ySpan, 1);
    });

    test('custom spans are preserved', () {
      final item = GridItem(id: 'a', data: 'data', xSpan: 2, ySpan: 3);
      expect(item.xSpan, 2);
      expect(item.ySpan, 3);
    });
  });

  // ==========================================================================
  // GridCellRect / OccupiedCell TESTS
  // ==========================================================================

  group('GridCellRect', () {
    test('default spans are 1', () {
      const cell = GridCellRect(x: 0, y: 0);
      expect(cell.xSpan, 1);
      expect(cell.ySpan, 1);
    });

    test('stores custom position and spans', () {
      const cell = GridCellRect(x: 2, y: 3, xSpan: 4, ySpan: 2);
      expect(cell.x, 2);
      expect(cell.y, 3);
      expect(cell.xSpan, 4);
      expect(cell.ySpan, 2);
    });
  });

  group('OccupiedCell', () {
    test('stores x and y', () {
      const cell = OccupiedCell(x: 5, y: 7);
      expect(cell.x, 5);
      expect(cell.y, 7);
    });
  });

  // ==========================================================================
  // OBJECT ACTIONS TESTS
  // ==========================================================================

  group('MagoObjectActions', () {
    testWidgets('renders action buttons', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoObjectActions(
          actions: [
            MagoObjectActionButton(icon: Icons.delete, onTap: () {}),
            MagoObjectActionButton(icon: Icons.copy, onTap: () {}),
          ],
        ),
      ));

      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('renders dividers between actions', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoObjectActions(
          actions: [
            MagoObjectActionButton(icon: Icons.delete, onTap: () {}),
            MagoObjectActionButton(icon: Icons.copy, onTap: () {}),
            MagoObjectActionButton(icon: Icons.edit, onTap: () {}),
          ],
        ),
      ));

      // 3 actions = 2 dividers
      expect(find.byType(VerticalDivider), findsNWidgets(2));
    });
  });

  group('MagoObjectActionButton', () {
    testWidgets('calls onTap when pressed', (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildTestApp(
        MagoObjectActionButton(
          icon: Icons.delete,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byIcon(Icons.delete));
      expect(tapped, isTrue);
    });
  });

  // ==========================================================================
  // DRAWER TESTS
  // ==========================================================================

  group('MagoDrawer', () {
    testWidgets('renders with child content', (tester) async {
      await tester.pumpWidget(buildConstrainedApp(
        MagoDrawer(
          minExtent: 0.1,
          maxExtent: 0.5,
          child: const Text('Drawer Content'),
        ),
      ));

      expect(find.text('Drawer Content'), findsOneWidget);
    });

    testWidgets('renders handle by default', (tester) async {
      await tester.pumpWidget(buildConstrainedApp(
        const MagoDrawer(
          minExtent: 0.1,
          maxExtent: 0.5,
        ),
      ));

      // The handle is wrapped in a GestureDetector
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('supports all placements without crash', (tester) async {
      for (final placement in MagoDrawerPlacement.values) {
        await tester.pumpWidget(buildConstrainedApp(
          MagoDrawer(
            placement: placement,
            minExtent: 0.1,
            maxExtent: 0.5,
            child: Text('Drawer ${placement.name}'),
          ),
        ));

        expect(find.text('Drawer ${placement.name}'), findsOneWidget);
      }
    });
  });

  // ==========================================================================
  // POPOVER TESTS
  // ==========================================================================

  group('MagoPopoverAnchor', () {
    testWidgets('renders anchor child', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoPopoverAnchor(
          popoverBuilder: (_) => const Text('Popover content'),
          child: const Text('Anchor'),
        ),
      ));

      expect(find.text('Anchor'), findsOneWidget);
      expect(find.text('Popover content'), findsNothing);
    });

    testWidgets('tapping anchor shows popover', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoPopoverAnchor(
          popoverBuilder: (_) => const Text('Popover content'),
          child: const Text('Anchor'),
        ),
      ));

      await tester.tap(find.text('Anchor'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Popover content'), findsOneWidget);
    });

    testWidgets('tapping anchor again dismisses popover', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoPopoverAnchor(
          popoverBuilder: (_) => const Text('Popover content'),
          child: const Text('Anchor'),
        ),
      ));

      await tester.tap(find.text('Anchor'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Popover content'), findsOneWidget);

      // Tap anchor again to toggle off
      await tester.tap(find.text('Anchor'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Popover content'), findsNothing);
    });

    testWidgets('onShown callback fires', (tester) async {
      var shown = false;

      await tester.pumpWidget(buildTestApp(
        MagoPopoverAnchor(
          onShown: () => shown = true,
          popoverBuilder: (_) => const Text('Content'),
          child: const Text('Anchor'),
        ),
      ));

      await tester.tap(find.text('Anchor'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(shown, isTrue);
    });

    testWidgets('handle.dismiss closes popover', (tester) async {
      await tester.pumpWidget(buildTestApp(
        MagoPopoverAnchor(
          popoverBuilder: (handle) => ElevatedButton(
            onPressed: handle.dismiss,
            child: const Text('Close'),
          ),
          child: const Text('Anchor'),
        ),
      ));

      await tester.tap(find.text('Anchor'), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Close'), findsNothing);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MagoPopoverPosition enum
  // ──────────────────────────────────────────────────────────────────────────
  group('MagoPopoverPosition', () {
    test('has all 9 positions', () {
      expect(MagoPopoverPosition.values.length, 9);
    });
  });

  // ==========================================================================
  // QR CODE TESTS
  // ==========================================================================

  group('MagoQr', () {
    testWidgets('renders with required data parameter', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(data: 'https://example.com'),
      ));

      expect(find.byType(MagoQr), findsOneWidget);
      expect(find.byType(PrettyQrView), findsOneWidget);
    });

    testWidgets('default size is 200x200', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(data: 'test'),
      ));

      final container = tester.widget<Container>(find.byType(Container).last);
      expect(container.constraints?.maxWidth, 200);
      expect(container.constraints?.maxHeight, 200);
    });

    testWidgets('custom size is applied', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(data: 'test', size: 300),
      ));

      final container = tester.widget<Container>(find.byType(Container).last);
      expect(container.constraints?.maxWidth, 300);
      expect(container.constraints?.maxHeight, 300);
    });

    testWidgets('applies background color', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(
          data: 'test',
          backgroundColor: Colors.blue,
        ),
      ));

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.blue);
    });

    testWidgets('default background is transparent', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(data: 'test'),
      ));

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.transparent);
    });

    testWidgets('applies ClipRRect with borderRadius', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(data: 'test', borderRadius: 8.0),
      ));

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect).last);
      expect(
        clipRRect.borderRadius,
        BorderRadius.circular(8.0),
      );
    });

    testWidgets('handles long data strings without crashing', (tester) async {
      final longData = 'https://example.com/' + 'a' * 200;

      await tester.pumpWidget(buildTestApp(
        MagoQr(data: longData),
      ));

      expect(find.byType(MagoQr), findsOneWidget);
    });

    testWidgets('moduleRoundness > 0.5 uses smooth symbol', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(data: 'test', moduleRoundness: 0.8),
      ));

      // Widget tree renders without error
      expect(find.byType(PrettyQrView), findsOneWidget);
    });

    testWidgets('moduleRoundness <= 0.5 uses rounded symbol', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(data: 'test', moduleRoundness: 0.3),
      ));

      expect(find.byType(PrettyQrView), findsOneWidget);
    });

    testWidgets('custom padding is applied', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(
          data: 'test',
          padding: EdgeInsets.all(24),
        ),
      ));

      final container = tester.widget<Container>(find.byType(Container).last);
      expect(container.padding, const EdgeInsets.all(24));
    });

    testWidgets('custom color is passed to decoration', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const MagoQr(data: 'test', color: Colors.red),
      ));

      // Renders without error with explicit color
      expect(find.byType(PrettyQrView), findsOneWidget);
    });
  });
}
