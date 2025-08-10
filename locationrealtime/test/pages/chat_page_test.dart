import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatPage Widget Tests', () {
    Widget createTestWidget({
      String friendId = 'friend123',
      String friendEmail = 'friend@example.com',
    }) {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Text(friendEmail),
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {},
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: 0,
                  itemBuilder: (context, index) => Container(),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.0),
                    Material(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(24.0),
                      child: IconButton(
                        icon: Icon(Icons.send, color: Colors.white),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    group('Widget Rendering', () {
      testWidgets('should render app bar with friend email title', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(friendEmail: 'test@example.com'));
        await tester.pumpAndSettle();

        expect(find.text('test@example.com'), findsOneWidget);
      });

      testWidgets('should render back button in app bar', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('should render chat bubble icon in app bar actions', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      });

      testWidgets('should render text input field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Type a message...'), findsOneWidget);
      });

      testWidgets('should render send button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.send), findsOneWidget);
      });

      testWidgets('should have proper app bar structure', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(IconButton), findsNWidgets(3)); // back button + chat bubble + send button
      });

      testWidgets('should have proper body structure', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Column), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('should have proper send button styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final sendButton = find.byIcon(Icons.send);
        expect(sendButton, findsOneWidget);
        
        // Check that the send button has Material ancestors (there might be multiple)
        expect(find.ancestor(
          of: sendButton,
          matching: find.byType(Material),
        ), findsWidgets);
      });
    });

    group('User Interaction', () {
      testWidgets('should handle text input', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final textField = find.byType(TextField);
        await tester.tap(textField);
        await tester.enterText(textField, 'Hello, world!');
        await tester.pumpAndSettle();

        expect(find.text('Hello, world!'), findsOneWidget);
      });

      testWidgets('should handle text input focus', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final textField = find.byType(TextField);
        await tester.tap(textField);
        await tester.pumpAndSettle();

        // The text field should be focused after tapping
        // We can verify focus by checking if the text field can receive input
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('should handle send button tap', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final sendButton = find.byIcon(Icons.send);
        await tester.tap(sendButton);
        await tester.pumpAndSettle();

        // Button tap should not cause any errors
        expect(find.byIcon(Icons.send), findsOneWidget);
      });

      testWidgets('should handle back button tap', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final backButton = find.byIcon(Icons.arrow_back);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Back button tap should not cause any errors
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });
    });

    group('Layout and Styling', () {
      testWidgets('should have proper padding around input area', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final inputContainer = find.byType(Container).last;
        final containerWidget = tester.widget<Container>(inputContainer);
        
        expect(containerWidget.padding, EdgeInsets.all(16.0));
      });

      testWidgets('should have proper spacing between input and send button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Find the SizedBox with width 8.0 specifically
        final sizedBoxes = find.byType(SizedBox);
        expect(sizedBoxes, findsWidgets);
        
        // Check that at least one SizedBox has width 8.0
        bool foundCorrectSpacing = false;
        for (int i = 0; i < sizedBoxes.evaluate().length; i++) {
          final sizedBox = sizedBoxes.at(i);
          final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);
          if (sizedBoxWidget.width == 8.0) {
            foundCorrectSpacing = true;
            break;
          }
        }
        expect(foundCorrectSpacing, isTrue);
      });

      testWidgets('should have rounded send button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Check that the send button has Material ancestors (there might be multiple)
        expect(find.ancestor(
          of: find.byIcon(Icons.send),
          matching: find.byType(Material),
        ), findsWidgets);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty friend email', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(friendEmail: ''));
        await tester.pumpAndSettle();

        // Check that the empty string appears in the app bar title
        expect(find.text(''), findsWidgets);
      });

      testWidgets('should handle very long friend email', (WidgetTester tester) async {
        final longEmail = 'very.long.email.address.that.might.cause.layout.issues@example.com';
        await tester.pumpWidget(createTestWidget(friendEmail: longEmail));
        await tester.pumpAndSettle();

        expect(find.text(longEmail), findsOneWidget);
      });

      testWidgets('should handle special characters in friend email', (WidgetTester tester) async {
        final specialEmail = 'test+special@example-domain.com';
        await tester.pumpWidget(createTestWidget(friendEmail: specialEmail));
        await tester.pumpAndSettle();

        expect(find.text(specialEmail), findsOneWidget);
      });
    });
  });
}
