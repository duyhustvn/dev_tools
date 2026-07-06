import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dev_tools_pro_max/image_tool.dart';
import 'package:dev_tools_pro_max/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MultiToolScreen()));
  }

  Future<void> openTimeTool(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
  }

  Future<void> enterDateTime(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('date-year-field')), '2026');
    await tester.enterText(find.byKey(const Key('date-month-field')), '07');
    await tester.enterText(find.byKey(const Key('date-day-field')), '03');
    await tester.enterText(find.byKey(const Key('date-hour-field')), '02');
    await tester.enterText(find.byKey(const Key('date-minute-field')), '37');
    await tester.enterText(find.byKey(const Key('date-second-field')), '01');
  }

  testWidgets('renders the tool navigation', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('Base64'), findsOneWidget);
    expect(find.text('URL'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('JWT'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('RPS/CCU'), findsOneWidget);
  });

  testWidgets('renders rps/ccu tool and calculates values', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('RPS/CCU'));
    await tester.pumpAndSettle();

    expect(find.text('Capacity Planning & k6 Generator'), findsOneWidget);
    expect(find.text('1. Thông số đầu vào'), findsOneWidget);
    expect(find.text('Kết quả dự kiến'), findsOneWidget);

    // Initial check of default calculated values (DAU = 3,000,000 * 10% = 300,000)
    expect(find.text('300.000'), findsOneWidget); // Daily Active Users (DAU)
    expect(find.text('3.000.000'), findsOneWidget); // Daily requests
    expect(find.text('1.389'), findsOneWidget); // Peak CCU
    expect(find.text('2.778'), findsOneWidget); // Design CCU
  });

  testWidgets('renders rps/ccu tool and performs reverse calculations', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('RPS/CCU'));
    await tester.pumpAndSettle();

    // Click the "Tính toán ngược" tab
    await tester.tap(find.text('Tính toán ngược (System -> Business)'));
    await tester.pumpAndSettle();

    expect(find.text('1. Thông số giới hạn hệ thống'), findsOneWidget);
    expect(find.text('Quy mô người dùng tối đa hệ thống chịu tải được'), findsOneWidget);

    expect(find.text('300.240'), findsOneWidget); // DAU tối đa
    expect(find.text('3.002.400'), findsNWidgets(2)); // Total Users tối đa & Daily requests tối đa
  });

  testWidgets('renders image tool empty state with disabled actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ImageTool()));

    expect(find.text('Image Tools'), findsOneWidget);
    expect(find.text('No image selected'), findsOneWidget);

    final removeButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('image-remove-background-button')),
    );
    final exportButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('image-export-button')),
    );

    expect(removeButton.onPressed, isNull);
    expect(exportButton.onPressed, isNull);
    expect(find.byKey(const Key('image-pick-button')), findsOneWidget);
    expect(
      find.byKey(const Key('image-background-mode-dropdown')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('image-tolerance-slider')), findsOneWidget);
    expect(find.byKey(const Key('image-feather-switch')), findsOneWidget);
  });

  testWidgets('converts GMT+7 date and time to Unix timestamp', (
    WidgetTester tester,
  ) async {
    await openTimeTool(tester);

    await enterDateTime(tester);
    await tester.ensureVisible(
      find.byKey(const Key('date-to-unix-convert-button')),
    );
    await tester.tap(find.byKey(const Key('date-to-unix-convert-button')));
    await tester.pump();

    expect(find.textContaining('Seconds: 1783021021'), findsOneWidget);
    expect(find.textContaining('Milliseconds: 1783021021000'), findsOneWidget);
  });

  testWidgets('updates visible time conversion when timezone changes', (
    WidgetTester tester,
  ) async {
    await openTimeTool(tester);

    expect(find.textContaining('GMT+7:'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('date-timezone-dropdown')));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('date-timezone-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GMT+6').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('GMT+6:'), findsOneWidget);
    expect(find.textContaining('GMT+7:'), findsNothing);
  });

  testWidgets('uses the selected timezone when converting date and time', (
    WidgetTester tester,
  ) async {
    await openTimeTool(tester);

    await enterDateTime(tester);
    await tester.ensureVisible(find.byKey(const Key('date-timezone-dropdown')));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('date-timezone-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GMT+6').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('date-to-unix-convert-button')),
    );
    await tester.tap(find.byKey(const Key('date-to-unix-convert-button')));
    await tester.pump();

    expect(find.textContaining('Seconds: 1783024621'), findsOneWidget);
    expect(find.textContaining('Milliseconds: 1783024621000'), findsOneWidget);
  });

  testWidgets('recalculates date and time after timezone changes', (
    WidgetTester tester,
  ) async {
    await openTimeTool(tester);

    await enterDateTime(tester);
    await tester.ensureVisible(
      find.byKey(const Key('date-to-unix-convert-button')),
    );
    await tester.tap(find.byKey(const Key('date-to-unix-convert-button')));
    await tester.pump();

    expect(find.textContaining('Seconds: 1783021021'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('date-timezone-dropdown')));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('date-timezone-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GMT+6').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Seconds: 1783021021'), findsNothing);
    expect(find.textContaining('Seconds: 1783024621'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('date-to-unix-convert-button')),
    );
    await tester.tap(find.byKey(const Key('date-to-unix-convert-button')));
    await tester.pump();

    expect(find.textContaining('Seconds: 1783021021'), findsNothing);
    expect(find.textContaining('Seconds: 1783024621'), findsOneWidget);
  });
}
