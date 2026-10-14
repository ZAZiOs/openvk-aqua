import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/models/attachment.dart';
import 'package:openvk_flutter/ui/widgets/retro_attachment_grid.dart';

void main() {
  group('RetroAttachmentGrid Widget Tests', () {
    testWidgets('Empty attachments list returns SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroAttachmentGrid(attachments: []),
          ),
        ),
      );

      expect(find.byType(RetroAttachmentGrid), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Renders single photo with natural aspect ratio', (tester) async {
      const photoAtt = Attachment(
        type: 'photo',
        photo: PhotoAttachment(
          id: 1,
          ownerId: 2,
          url: 'https://vk.com/photo1.jpg',
          width: 800,
          height: 600,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroAttachmentGrid(attachments: [photoAtt]),
          ),
        ),
      );

      expect(find.byType(AspectRatio), findsOneWidget);
      final aspectRatioFinder = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatioFinder.aspectRatio, closeTo(800 / 600, 0.01));
    });

    testWidgets('Renders 2 photos side by side in a Row', (tester) async {
      const photos = [
        Attachment(
          type: 'photo',
          photo: PhotoAttachment(
            id: 1,
            ownerId: 2,
            url: 'https://vk.com/p1.jpg',
            width: 500,
            height: 500,
          ),
        ),
        Attachment(
          type: 'photo',
          photo: PhotoAttachment(
            id: 2,
            ownerId: 2,
            url: 'https://vk.com/p2.jpg',
            width: 500,
            height: 500,
          ),
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroAttachmentGrid(attachments: photos),
          ),
        ),
      );

      // Should find a Row containing both items
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('Renders video with duration and play button', (tester) async {
      const videoAtt = Attachment(
        type: 'video',
        video: VideoAttachment(
          id: 10,
          ownerId: 20,
          title: 'Прикольное видео',
          duration: 125, // 2:05
          photoUrl: 'https://vk.com/thumb.jpg',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroAttachmentGrid(attachments: [videoAtt]),
          ),
        ),
      );

      expect(find.text('2:05'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('Renders audio track with artist, title, and formatted duration', (tester) async {
      const audioAtt = Attachment(
        type: 'audio',
        audio: AudioAttachment(
          id: 100,
          ownerId: 200,
          artist: 'Гражданская Оборона',
          title: 'Моя оборона',
          duration: 213, // 3:33
          url: '',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroAttachmentGrid(attachments: [audioAtt]),
          ),
        ),
      );

      expect(find.text('Гражданская Оборона'), findsOneWidget);
      expect(find.text('Моя оборона'), findsOneWidget);
      expect(find.text('3:33'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('Renders document with uppercase ext, title, and formatted size', (tester) async {
      const docAtt = Attachment(
        type: 'doc',
        doc: DocAttachment(
          id: 50,
          ownerId: 60,
          title: 'Курсовая работа.pdf',
          size: 2097152, // 2.0 МБ
          ext: 'pdf',
          url: 'https://vk.com/doc50',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroAttachmentGrid(attachments: [docAtt]),
          ),
        ),
      );

      expect(find.text('Курсовая работа.pdf'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('2.0 МБ'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });

    testWidgets('Renders mixed attachments (photo + audio + doc) correctly', (tester) async {
      const attachments = [
        Attachment(
          type: 'photo',
          photo: PhotoAttachment(
            id: 1,
            ownerId: 2,
            url: 'https://vk.com/p1.jpg',
            width: 400,
            height: 300,
          ),
        ),
        Attachment(
          type: 'audio',
          audio: AudioAttachment(
            id: 2,
            ownerId: 2,
            artist: 'Linkin Park',
            title: 'Numb',
            duration: 187,
            url: '',
          ),
        ),
        Attachment(
          type: 'doc',
          doc: DocAttachment(
            id: 3,
            ownerId: 2,
            title: 'notes.txt',
            size: 1536,
            ext: 'txt',
            url: '',
          ),
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RetroAttachmentGrid(attachments: attachments),
          ),
        ),
      );

      expect(find.text('Linkin Park'), findsOneWidget);
      expect(find.text('Numb'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('TXT'), findsOneWidget);
      expect(find.text('1.5 КБ'), findsOneWidget);
    });
  });
}
