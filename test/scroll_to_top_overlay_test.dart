import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/scroll_to_top_overlay.dart';

void main() {
  testWidgets('scroll-to-top control fades in and returns the page to top', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ScrollToTopOverlay(
          child: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (context, index) =>
                  SizedBox(height: 80, child: Text('Item $index')),
            ),
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('scroll-to-top-button'));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(of: button, matching: find.byType(AnimatedOpacity))
                .first,
          )
          .opacity,
      0,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(240));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(of: button, matching: find.byType(AnimatedOpacity))
                .first,
          )
          .opacity,
      1,
    );
    expect(find.bySemanticsLabel('Scroll to top'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(of: button, matching: find.byType(AnimatedOpacity))
                .first,
          )
          .opacity,
      0,
    );

    controller.dispose();
  });
}
