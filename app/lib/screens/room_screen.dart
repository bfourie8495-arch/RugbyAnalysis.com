import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/chat_widgets.dart';
import 'chat_screen.dart' show askRoomName;

/// Opens a room you're in; [invite] shows the invite straight away (a room you've just made).
Future<void> openRoom(BuildContext context, String id, {bool invite = false}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(id: id, showInvite: invite)));

/// A chat room: the match it's watching at the top, the messages, and a box to write in.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.id, this.showInvite = false});

  final String id;
  final bool showInvite;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _text = TextEditingController();
  late final Stream<List<ChatMessage>> _messages;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context);
    _messages = c.chat!.messages(widget.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      c.markSeen(widget.id);
      final r = c.room(widget.id);
      if (widget.showInvite && r != null) showInvite(context, r);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(Room r) async {
    final t = _text.text;
    if (t.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await AppScope.read(context).send(r, t);
      _text.clear();
    } catch (e) {
      if (mounted) _say('Couldn’t send that. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _say(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final r = c.room(widget.id);
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(
          child: c.roomsLoaded
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('You’re not in this room any more.', textAlign: TextAlign.center, style: TextStyle(color: RaColors.muted)),
                )
              : const CircularProgressIndicator(color: RaColors.gold),
        ),
      );
    }
    final me = c.myUid ?? '';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          RoomAvatar(room: r, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, overflow: TextOverflow.ellipsis),
              Text(r.peopleLine(me), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: RaColors.faint, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
        actions: [
          IconButton(tooltip: 'Invite friends', onPressed: () => showInvite(context, r), icon: const Icon(Icons.person_add_alt_1)),
          _RoomMenu(room: r),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: r.match != null
              ? PinnedMatchCard(match: r.match!, onClear: () => c.pinMatch(r, null))
              : SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), side: const BorderSide(color: RaColors.line2)),
                    onPressed: () => _pin(r),
                    icon: const Icon(Icons.push_pin_outlined, size: 18),
                    label: const Text('Pin the match you’re watching', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messages,
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Couldn’t load the messages. Check your connection.', style: TextStyle(color: RaColors.muted))));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: RaColors.gold));
              final msgs = [for (final m in snap.data!) if (!c.blocked.contains(m.uid)) m];
              if (c.hasUnread(r)) WidgetsBinding.instance.addPostFrameCallback((_) => c.markSeen(r.id));
              // reverse: true keeps the newest message at the bottom, by the box, like any messaging app.
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                itemCount: msgs.length + 1,
                itemBuilder: (context, i) {
                  if (i == msgs.length) return const _RoomStart();
                  final m = msgs[msgs.length - 1 - i];
                  final prev = msgs.length - 2 - i >= 0 ? msgs[msgs.length - 2 - i] : null;
                  return _Bubble(room: r, message: m, mine: m.uid == me, showName: prev?.uid != m.uid);
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: const BoxDecoration(color: RaColors.bar, border: Border(top: BorderSide(color: RaColors.line))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: maxMessageLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: RaColors.card,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22)), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _send(r),
                ),
              ),
              IconButton(
                tooltip: 'Send',
                onPressed: _sending ? null : () => _send(r),
                icon: const Icon(Icons.send_rounded, color: RaColors.gold),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _pin(Room r) async {
    final m = await pickMatch(context);
    if (m == null || !mounted) return;
    await AppScope.read(context).pinMatch(r, m);
  }
}

class _RoomStart extends StatelessWidget {
  const _RoomStart();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Text('Only people you invite can read this room. Messages are deleted after 30 days.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: RaColors.faint)),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.room, required this.message, required this.mine, required this.showName});

  final Room room;
  final ChatMessage message;
  final bool mine;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Padding(
      padding: EdgeInsets.only(top: showName ? 10 : 3),
      child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        if (showName && !mine)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 3),
            child: Text(m.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RaColors.goldSoft)),
          ),
        GestureDetector(
          onLongPress: () => _actions(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: mine ? RaColors.gold : RaColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
                border: mine ? null : Border.all(color: RaColors.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(m.text, style: TextStyle(fontSize: 15, color: mine ? RaColors.onGold : RaColors.ink, height: 1.3)),
                ),
                if (m.at != null) ...[
                  const SizedBox(height: 2),
                  Text(chatTime(m.at!), style: TextStyle(fontSize: 10, color: mine ? RaColors.onGold.withValues(alpha: 0.7) : RaColors.faint)),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _actions(BuildContext context) async {
    final c = AppScope.read(context);
    final me = c.myUid ?? '';
    final canDelete = mine || room.isOwner(me);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RaColors.card,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (canDelete)
            ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete message'), onTap: () => Navigator.of(sheet).pop('delete')),
          if (!mine) ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report message'),
              subtitle: const Text('We’ll look at it, and you won’t see their messages again.'),
              onTap: () => Navigator.of(sheet).pop('report'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text('Hide messages from ${message.name}'),
              subtitle: const Text('Only on your phone. They won’t know.'),
              onTap: () => Navigator.of(sheet).pop('block'),
            ),
          ],
        ]),
      ),
    );
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (choice) {
        case 'delete':
          await c.deleteMessage(room, message);
        case 'report':
          final reason = await _reportReason(context);
          if (reason == null) return;
          await c.report(room, message, reason);
          messenger.showSnackBar(const SnackBar(content: Text('Thanks. We’ve got your report, and their messages are hidden.')));
        case 'block':
          c.block(message.uid);
          messenger.showSnackBar(SnackBar(content: Text('Messages from ${message.name} are hidden. Undo this in Me.')));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('That didn’t work. Check your connection and try again.')));
    }
  }

  Future<String?> _reportReason(BuildContext context) => showModalBottomSheet<String>(
        context: context,
        backgroundColor: RaColors.card,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('What’s wrong with it?', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final r in ['Abuse or bullying', 'Hate speech', 'Spam or scams', 'Sexual content', 'Something else'])
              ListTile(title: Text(r), onTap: () => Navigator.of(sheet).pop(r)),
          ]),
        ),
      );
}

class _RoomMenu extends StatelessWidget {
  const _RoomMenu({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final me = c.myUid ?? '';
    final muted = room.muted.contains(me);
    final owner = room.isOwner(me);
    return PopupMenuButton<String>(
      tooltip: 'Room options',
      color: RaColors.card,
      onSelected: (v) => _act(context, v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'pin', child: Text('Pin a match')),
        const PopupMenuItem(value: 'rename', child: Text('Rename room')),
        PopupMenuItem(value: 'mute', child: Text(muted ? 'Turn on alerts for this room' : 'Mute alerts for this room')),
        const PopupMenuItem(value: 'leave', child: Text('Leave room')),
        if (owner) const PopupMenuItem(value: 'delete', child: Text('Delete room for everyone')),
      ],
    );
  }

  Future<void> _act(BuildContext context, String v) async {
    final c = AppScope.read(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (v) {
        case 'pin':
          final m = await pickMatch(context);
          if (m != null) await c.pinMatch(room, m);
        case 'rename':
          final n = await askRoomName(context, room.name);
          if (n != null) await c.renameRoom(room, n);
        case 'mute':
          await c.muteRoom(room, !room.muted.contains(c.myUid));
        case 'leave':
          if (!await _confirm(context, 'Leave ${room.name}?', 'You won’t see its messages any more. A friend can invite you back.', 'Leave')) return;
          await c.leaveRoom(room);
          nav.pop();
        case 'delete':
          if (!await _confirm(context, 'Delete ${room.name}?', 'This deletes the room and every message in it, for everyone. It can’t be undone.', 'Delete')) {
            return;
          }
          await c.deleteRoom(room);
          nav.pop();
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('That didn’t work. Check your connection and try again.')));
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: RaColors.card,
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(d).pop(true), child: Text(action)),
          ],
        ),
      ) ??
      false;
}
