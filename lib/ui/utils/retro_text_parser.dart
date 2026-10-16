import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/retro_theme.dart';

/// Utility to parse VK mentions ([id123|Name], [club123|Name]) and web URLs (https://...)
/// into interactive InlineSpan lists with iOS 6 style.
class RetroTextParser {
  const RetroTextParser._();

  static final RegExp _pattern = RegExp(
    r'(?:\[(id|club|public|event)(\d+)\|([^\]]+)\])|' // [id123|name] or [club123|name]
    r'(?:(?:@|\*)(id|club|public|event)(\d+)\s*\(([^)]+)\))|' // @id123 (name)
    r'''(https?://[^\s<>"'\(\)\[\]{}]+)''', // https://...
    caseSensitive: false,
  );

  static List<InlineSpan> buildSpans({
    required String text,
    required TextStyle defaultStyle,
    TextStyle? linkStyle,
    void Function(int ownerId)? onOpenProfile,
    void Function(String url)? onOpenUrl,
  }) {
    if (text.isEmpty) return const [];

    final effectiveLinkStyle = linkStyle ??
        defaultStyle.copyWith(
          color: RetroTheme.textLink,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        );

    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    for (final match in _pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: defaultStyle,
        ));
      }

      // 1. [id123|Name] or [club123|Name]
      if (match.group(1) != null) {
        final prefix = match.group(1)!.toLowerCase();
        final idNum = int.tryParse(match.group(2)!) ?? 0;
        final label = match.group(3) ?? '';
        final ownerId = (prefix == 'id') ? idNum : -idNum;

        spans.add(TextSpan(
          text: label,
          style: effectiveLinkStyle,
          recognizer: onOpenProfile != null
              ? (TapGestureRecognizer()..onTap = () => onOpenProfile(ownerId))
              : null,
        ));
      }
      // 2. @id123 (Name) or *club123 (Name)
      else if (match.group(4) != null) {
        final prefix = match.group(4)!.toLowerCase();
        final idNum = int.tryParse(match.group(5)!) ?? 0;
        final label = match.group(6) ?? '';
        final ownerId = (prefix == 'id') ? idNum : -idNum;

        spans.add(TextSpan(
          text: label,
          style: effectiveLinkStyle,
          recognizer: onOpenProfile != null
              ? (TapGestureRecognizer()..onTap = () => onOpenProfile(ownerId))
              : null,
        ));
      }
      // 3. Web URL
      else if (match.group(7) != null) {
        var rawUrl = match.group(7)!;
        int trimmedCount = 0;
        // Trim trailing punctuation marks like '.', ',', '!', '?'
        while (rawUrl.isNotEmpty &&
            (rawUrl.endsWith('.') ||
                rawUrl.endsWith(',') ||
                rawUrl.endsWith(';') ||
                rawUrl.endsWith(':') ||
                rawUrl.endsWith('!') ||
                rawUrl.endsWith('?'))) {
          rawUrl = rawUrl.substring(0, rawUrl.length - 1);
          trimmedCount++;
        }

        final targetUrl = rawUrl;
        spans.add(TextSpan(
          text: targetUrl,
          style: effectiveLinkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (onOpenUrl != null) {
                onOpenUrl(targetUrl);
              } else {
                openExternalUrl(targetUrl, onOpenProfile: onOpenProfile);
              }
            },
        ));

        lastMatchEnd = match.end - trimmedCount;
        continue;
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: defaultStyle,
      ));
    }

    return spans;
  }

  static Future<void> openExternalUrl(
    String url, {
    void Function(int ownerId)? onOpenProfile,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      // Check if it's an internal openvk/vk link like /id123 or /club123
      if (onOpenProfile != null) {
        final path = uri.path.replaceAll('/', '');
        final userMatch = RegExp(r'^id(\d+)$', caseSensitive: false).firstMatch(path);
        if (userMatch != null) {
          final uid = int.tryParse(userMatch.group(1)!) ?? 0;
          if (uid > 0) {
            onOpenProfile(uid);
            return;
          }
        }
        final groupMatch = RegExp(r'^(club|public|event)(\d+)$', caseSensitive: false).firstMatch(path);
        if (groupMatch != null) {
          final gid = int.tryParse(groupMatch.group(2)!) ?? 0;
          if (gid > 0) {
            onOpenProfile(-gid);
            return;
          }
        }
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

/// A text widget that renders VK mentions and URLs as clickable links.
class RetroLinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final void Function(int ownerId)? onOpenProfile;
  final void Function(String url)? onOpenUrl;

  const RetroLinkifiedText({
    super.key,
    required this.text,
    required this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onOpenProfile,
    this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final spans = RetroTextParser.buildSpans(
      text: text,
      defaultStyle: style,
      linkStyle: linkStyle,
      onOpenProfile: onOpenProfile,
      onOpenUrl: onOpenUrl,
    );

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
