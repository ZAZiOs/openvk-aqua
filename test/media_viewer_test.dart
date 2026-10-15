import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/models/attachment.dart';
import 'package:openvk_aqua/ui/widgets/retro_attachment_grid.dart';
import 'package:openvk_aqua/ui/widgets/retro_media_viewer.dart';

void main() {
  final testPhotos = [
    const Attachment(
      type: 'photo',
      photo: PhotoAttachment(
        id: 101,
        ownerId: 202,
        url: 'https://example.com/photo1.jpg',
        width: 800,
        height: 600,
        text: 'Красивый закат',
      ),
    ),
    const Attachment(
      type: 'video',
      video: VideoAttachment(
        id: 303,
        ownerId: 202,
        title: 'Тестовый видеоролик',
        duration: 135,
        photoUrl: 'https://example.com/video_thumb.jpg',
        description: 'Описание видео',
      ),
    ),
    const Attachment(
      type: 'photo',
      photo: PhotoAttachment(
        id: 102,
        ownerId: 202,
        url: 'https://example.com/photo2.jpg',
        width: 1024,
        height: 768,
        text: 'Горы и море',
      ),
    ),
  ];

  group('RetroMediaViewer Widget Tests', () {
    testWidgets('Opens viewer at initialIndex and displays counter and title',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroMediaViewer(
              items: testPhotos,
              initialIndex: 0,
            ),
          ),
        ),
      );

      // Total 3 items, at index 0 => "1 из 3"
      expect(find.text('1 из 3'), findsOneWidget);
      expect(find.text('Фотография'), findsOneWidget);
      expect(find.text('Красивый закат'), findsOneWidget);

      // Verify close and download buttons are rendered
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });

    testWidgets('Initial index 1 displays video details and duration',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroMediaViewer(
              items: testPhotos,
              initialIndex: 1,
            ),
          ),
        ),
      );

      expect(find.text('2 из 3'), findsOneWidget);
      expect(find.text('Видеозапись'), findsOneWidget);
      expect(find.text('Тестовый видеоролик'), findsWidgets);
      expect(find.text('Длительность: 2:15 • Описание видео'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
    });

    testWidgets('Can swipe between neighboring items using navigation arrows',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroMediaViewer(
              items: testPhotos,
              initialIndex: 0,
            ),
          ),
        ),
      );

      expect(find.text('1 из 3'), findsOneWidget);

      // Click right navigation arrow
      final rightArrow = find.byTooltip('Следующее (→)');
      expect(rightArrow, findsOneWidget);
      await tester.tap(rightArrow);
      await tester.pumpAndSettle();

      // Now at item 2
      expect(find.text('2 из 3'), findsOneWidget);
      expect(find.text('Видеозапись'), findsOneWidget);

      // Click right navigation arrow again
      await tester.tap(find.byTooltip('Следующее (→)'));
      await tester.pumpAndSettle();

      // Now at item 3
      expect(find.text('3 из 3'), findsOneWidget);
      expect(find.text('Горы и море'), findsOneWidget);

      // Left arrow to go back
      final leftArrow = find.byTooltip('Предыдущее (←)');
      expect(leftArrow, findsOneWidget);
      await tester.tap(leftArrow);
      await tester.pumpAndSettle();

      // Back to item 2
      expect(find.text('2 из 3'), findsOneWidget);
    });

    testWidgets('Swipe gesture horizontally moves to next item', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroMediaViewer(
              items: testPhotos,
              initialIndex: 0,
            ),
          ),
        ),
      );

      expect(find.text('1 из 3'), findsOneWidget);

      // Drag left to swipe to page 2
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('2 из 3'), findsOneWidget);
    });

    testWidgets('Close button pops navigator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => RetroMediaViewer.open(
                  context,
                  items: testPhotos,
                  initialIndex: 0,
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      expect(find.byType(RetroMediaViewer), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(RetroMediaViewer), findsNothing);
    });

    testWidgets('Tapping attachment in RetroAttachmentGrid opens RetroMediaViewer',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroAttachmentGrid(
              attachments: testPhotos,
            ),
          ),
        ),
      );

      // Grid is rendered
      expect(find.byType(RetroAttachmentGrid), findsOneWidget);

      // Tap the second media item (which is a video or cell in the grid)
      final cells = find.byType(GestureDetector);
      expect(cells, findsWidgets);

      await tester.tap(cells.at(1));
      await tester.pumpAndSettle();

      // Should have opened RetroMediaViewer at index 1!
      expect(find.byType(RetroMediaViewer), findsOneWidget);
      expect(find.text('2 из 3'), findsOneWidget);
    });

    testWidgets('Tapping play in viewer opens RetroVideoPlayerView in iOS 6 style',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroMediaViewer(
              items: testPhotos,
              initialIndex: 1, // Video
            ),
          ),
        ),
      );

      // Tap the large center play button or "Смотреть"
      final playButton = find.text('Смотреть');
      expect(playButton, findsOneWidget);

      await tester.tap(playButton);
      await tester.pumpAndSettle();

      // Top bar "Готово" button is visible
      expect(find.text('Готово'), findsOneWidget);
      expect(find.text('Тестовый видеоролик'), findsWidgets);
    });
  });
}
