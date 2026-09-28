import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/merchant_news_cards_section.dart';

void main() {
  testWidgets('complete drafts can be published and incomplete cards cannot', (
    tester,
  ) async {
    Map<String, dynamic>? publishRequested;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MerchantNewsCardsSection(
            businesses: [
              {'id': 1, 'name': 'Draft venue'},
              {'id': 2, 'name': 'No image venue'},
              {'id': 3, 'name': 'Published venue'},
            ],
            posts: [
              {
                'businessId': 1,
                'title': 'Draft update',
                'body': 'Update body',
                'imageUrl': 'venue.jpg',
                'status': 'draft',
              },
              {
                'businessId': 2,
                'title': 'Image-less update',
                'body': 'Update body',
                'status': 'published',
              },
              {
                'businessId': 3,
                'title': 'Published update',
                'body': 'Update body',
                'imageUrl': 'venue.jpg',
                'status': 'published',
              },
            ],
            loading: false,
            onComplete: (_) {},
            onEdit: (_) {},
            onDelete: (_) {},
            onPublish: (post) => publishRequested = post,
          ),
        ),
      ),
    );

    expect(find.text('Draft update'), findsOneWidget);
    expect(find.text('Create news card'), findsNothing);
    expect(find.text('No image venue'), findsOneWidget);
    expect(find.text('Published venue'), findsNothing);
    expect(
      find.textContaining('News Card incomplete — add a short venue update.'),
      findsOneWidget,
    );
    expect(find.text('Published update'), findsOneWidget);

    await tester.tap(find.text('Publish'));
    expect(publishRequested?['businessId'], 1);
  });
}
