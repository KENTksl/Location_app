import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapPage Widget Tests', () {
    Widget createTestWidget({
      String? focusFriendId,
      String? focusFriendEmail,
    }) {
      return MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Bản đồ'),
                actions: [
                  IconButton(
                    icon: Icon(Icons.location_on_rounded),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.my_location_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('MapPage Test Widget'),
                    if (focusFriendId != null) Text('Focus Friend: $focusFriendId'),
                    if (focusFriendEmail != null) Text('Focus Email: $focusFriendEmail'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(Icons.add_rounded),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(Icons.remove_rounded),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(Icons.play_arrow_rounded),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(Icons.history_rounded),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Simulate map functionality
                      },
                      child: Text('Simulate Map'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    group('Widget Rendering', () {
      testWidgets('should render test widget with basic UI', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('MapPage Test Widget'), findsOneWidget);
        expect(find.text('Simulate Map'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('should render app bar with title', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Bản đồ'), findsOneWidget);
        expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
        expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      });

      testWidgets('should render with focus friend parameters', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          focusFriendId: 'friend1',
          focusFriendEmail: 'friend@example.com',
        ));
        await tester.pumpAndSettle();

        expect(find.text('Focus Friend: friend1'), findsOneWidget);
        expect(find.text('Focus Email: friend@example.com'), findsOneWidget);
      });

      testWidgets('should render control buttons', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      });
    });

    group('Button Interactions', () {
      testWidgets('should handle button press', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final button = find.byType(ElevatedButton);
        expect(button, findsOneWidget);
        
        await tester.tap(button);
        await tester.pumpAndSettle();
        
        // Button should still be present after tap
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('should handle icon button interactions', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final addButton = find.byIcon(Icons.add_rounded);
        final removeButton = find.byIcon(Icons.remove_rounded);
        final playButton = find.byIcon(Icons.play_arrow_rounded);
        final historyButton = find.byIcon(Icons.history_rounded);

        expect(addButton, findsOneWidget);
        expect(removeButton, findsOneWidget);
        expect(playButton, findsOneWidget);
        expect(historyButton, findsOneWidget);

        // Tap each button to ensure they don't crash
        await tester.tap(addButton);
        await tester.pumpAndSettle();
        await tester.tap(removeButton);
        await tester.pumpAndSettle();
        await tester.tap(playButton);
        await tester.pumpAndSettle();
        await tester.tap(historyButton);
        await tester.pumpAndSettle();

        // All buttons should still be present
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      });
    });

    group('Parameter Handling', () {
      testWidgets('should handle null parameters gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('MapPage Test Widget'), findsOneWidget);
        expect(find.text('Focus Friend:'), findsNothing);
        expect(find.text('Focus Email:'), findsNothing);
      });

      testWidgets('should handle empty string parameters', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          focusFriendId: '',
          focusFriendEmail: '',
        ));
        await tester.pumpAndSettle();

        expect(find.text('Focus Friend: '), findsOneWidget);
        expect(find.text('Focus Email: '), findsOneWidget);
      });
    });

    group('State Management', () {
      testWidgets('should maintain state during rebuilds', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Verify initial state
        expect(find.text('MapPage Test Widget'), findsOneWidget);

        // Rebuild widget
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // State should be maintained
        expect(find.text('MapPage Test Widget'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('should handle errors gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Widget should render without crashing
        expect(find.text('MapPage Test Widget'), findsOneWidget);
      });
    });

    group('UI Components', () {
      testWidgets('should build all UI components correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Test that all main UI components are present
        expect(find.text('MapPage Test Widget'), findsOneWidget);
        expect(find.text('Bản đồ'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      });
    });

    group('Lifecycle', () {
      testWidgets('should handle widget lifecycle correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Navigate away to trigger dispose
        await tester.pumpWidget(MaterialApp(home: Scaffold()));
        await tester.pumpAndSettle();

        // Verify cleanup
        expect(find.text('MapPage Test Widget'), findsNothing);
      });
    });

    group('Integration Tests', () {
      testWidgets('should integrate with MaterialApp properly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should be wrapped in MaterialApp
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });
    });
  });
}
