import 'package:flutter/material.dart';

import '../../core/api/messages_handler.dart';
import '../../core/api/openvk_client.dart';
import '../../core/models/message.dart';
import '../../core/models/message_viewers_response.dart';
import '../../core/models/user.dart';
import 'retro_avatar.dart';
import 'retro_loading_indicator.dart';

Future<void> showMessageViewersDialog({
  required BuildContext context,
  required OpenVkClient client,
  required int peerId,
  required Message message,
  required void Function(int userId) onUserTap,
}) {
  return showDialog(
    context: context,
    barrierColor: const Color(0x73000000),
    builder: (ctx) => _MessageViewersDialog(
      client: client,
      peerId: peerId,
      message: message,
      onUserTap: onUserTap,
    ),
  );
}

class _MessageViewersDialog extends StatefulWidget {
  final OpenVkClient client;
  final int peerId;
  final Message message;
  final void Function(int userId) onUserTap;

  const _MessageViewersDialog({
    required this.client,
    required this.peerId,
    required this.message,
    required this.onUserTap,
  });

  @override
  State<_MessageViewersDialog> createState() => _MessageViewersDialogState();
}

class _MessageViewersDialogState extends State<_MessageViewersDialog> {
  late Future<MessageViewersResponse> _viewersFuture;

  @override
  void initState() {
    super.initState();
    _viewersFuture = _loadViewers();
  }

  Future<MessageViewersResponse> _loadViewers() async {
    final handler = MessagesHandler(widget.client);
    final res = await handler.getMessageViewers(
      peerId: widget.peerId,
      messageId: widget.message.id,
      conversationMessageId: widget.message.conversationMessageId,
    );
    if (res.isSuccess && res.dataOrNull != null) {
      return res.dataOrNull!;
    }
    return MessageViewersResponse.empty();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xF01D2D42),
                Color(0xF80E1826),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                offset: Offset(0, 8),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: Stack(
              children: [
                // iOS 6 glass gloss highlight
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Кто посмотрел',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, -1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<MessageViewersResponse>(
                        future: _viewersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  RetroLoadingIndicator(size: 20),
                                  SizedBox(height: 10),
                                  Text(
                                    'Загрузка просмотров...',
                                    style: TextStyle(
                                      color: Color(0xFFD6E3F2),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final response = snapshot.data;
                          final items = response?.items ?? [];
                          final profilesMap = {
                            for (final p in (response?.profiles ?? <User>[]))
                              p.id: p,
                            ...widget.client.userCache.users,
                          };

                          if (items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'Пока никто не посмотрел это сообщение',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFD6E3F2),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            );
                          }

                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 250),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: items.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(
                                color: Color(0x33FFFFFF),
                                height: 8,
                                thickness: 0.8,
                              ),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final user = profilesMap[item.userId];
                                final name = user?.fullName.isNotEmpty == true
                                    ? user!.fullName
                                    : 'Пользователь #${item.userId}';

                                return InkWell(
                                  onTap: () => widget.onUserTap(item.userId),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        RetroAvatar(
                                          url: user?.avatarUrl,
                                          fallbackText: name,
                                          size: 32,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black54,
                                                  offset: Offset(0, 1),
                                                  blurRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (user?.isOnline == true) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF4CD964),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(0x66000000),
                                                  offset: Offset(0, 1),
                                                  blurRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Close button in classic iOS 6 glass style
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF5B697A),
                                  Color(0xFF333D4B),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF222832),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  offset: Offset(0, 1.5),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Закрыть',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      offset: Offset(0, -1),
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
