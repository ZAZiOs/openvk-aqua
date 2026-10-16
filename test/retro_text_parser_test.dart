import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/models/attachment.dart';
import 'package:openvk_aqua/ui/utils/retro_text_parser.dart';
import 'package:openvk_aqua/ui/widgets/retro_attachment_grid.dart';

void main() {
  group('RetroTextParser', () {
    test('parses [id123|Имя] and calls onOpenProfile with positive ID', () {
      int? openedOwnerId;
      final spans = RetroTextParser.buildSpans(
        text: 'Привет, [id123|Алексей]!',
        defaultStyle: const TextStyle(color: Colors.black),
        onOpenProfile: (id) => openedOwnerId = id,
      );

      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, 'Привет, ');
      expect((spans[1] as TextSpan).text, 'Алексей');
      expect((spans[2] as TextSpan).text, '!');

      final recognizer = (spans[1] as TextSpan).recognizer as TapGestureRecognizer;
      recognizer.onTap!();
      expect(openedOwnerId, 123);
    });

    test('parses [club456|Сообщество] and calls onOpenProfile with negative ID', () {
      int? openedOwnerId;
      final spans = RetroTextParser.buildSpans(
        text: 'Зайди в [club456|Открытый ВКонтакте]',
        defaultStyle: const TextStyle(color: Colors.black),
        onOpenProfile: (id) => openedOwnerId = id,
      );

      expect(spans.length, 2);
      expect((spans[0] as TextSpan).text, 'Зайди в ');
      expect((spans[1] as TextSpan).text, 'Открытый ВКонтакте');

      final recognizer = (spans[1] as TextSpan).recognizer as TapGestureRecognizer;
      recognizer.onTap!();
      expect(openedOwnerId, -456);
    });

    test('parses web URLs and strips trailing punctuation', () {
      String? openedUrl;
      final spans = RetroTextParser.buildSpans(
        text: 'Смотри сайт https://openvk.su/doc/test. Понял?',
        defaultStyle: const TextStyle(color: Colors.black),
        onOpenUrl: (url) => openedUrl = url,
      );

      expect(spans.length, 3);
      expect((spans[0] as TextSpan).text, 'Смотри сайт ');
      expect((spans[1] as TextSpan).text, 'https://openvk.su/doc/test');
      expect((spans[2] as TextSpan).text, '. Понял?');

      final recognizer = (spans[1] as TextSpan).recognizer as TapGestureRecognizer;
      recognizer.onTap!();
      expect(openedUrl, 'https://openvk.su/doc/test');
    });

    testWidgets('RetroLinkifiedText renders clickable spans in widget tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroLinkifiedText(
              text: 'Привет [id777|Павел Дуров], чекни https://openvk.su!',
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ),
      );

      expect(find.textContaining('Привет', findRichText: true), findsOneWidget);
      expect(find.textContaining('Павел Дуров', findRichText: true), findsOneWidget);
      expect(find.textContaining('https://openvk.su', findRichText: true), findsOneWidget);
    });

    testWidgets('RetroAttachmentGrid excludes link attachment stubs and renders wall attachments as "Нажмите, чтобы открыть запись"', (tester) async {
      final attachments = <Attachment>[
        const Attachment(
          type: 'link',
        ),
        const Attachment(
          type: 'wall',
          wall: WallAttachment(
            id: 101,
            ownerId: 202,
            fromId: 202,
            date: 1700000000,
            text: 'Пост на стене',
          ),
        ),
      ];

      Attachment? tappedAttachment;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetroAttachmentGrid(
              attachments: attachments,
              onAttachmentTap: (att, idx) => tappedAttachment = att,
            ),
          ),
        ),
      );

      // Link attachment stub like "[Ссылка]" should NOT be rendered
      expect(find.textContaining('[Ссылка]'), findsNothing);
      expect(find.textContaining('Ссылка'), findsNothing);

      // Wall attachment button should be rendered
      expect(find.text('Нажмите, чтобы открыть запись'), findsOneWidget);

      // Tap on the wall attachment
      await tester.tap(find.text('Нажмите, чтобы открыть запись'));
      await tester.pump();

      expect(tappedAttachment, isNotNull);
      expect(tappedAttachment!.type, 'wall');
      expect(tappedAttachment!.wall?.id, 101);
    });
  });
}
