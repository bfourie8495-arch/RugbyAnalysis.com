import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/common.dart';
import 'room_screen.dart';

/// The Chat tab: your rooms (private, for friends you invite), a new room, or join one with its code.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      Text('Chat', style: displayStyle(22)),
      const SizedBox(height: 4),
      const Text('Private rooms for you and your friends. Only people you send the invite to can join.',
          style: TextStyle(color: RaColors.muted, fontSize: 13)),
      const SizedBox(height: 14),
      if (!c.chatAvailable)
        const EmptyNote('Chat isn’t available', 'Chat needs a connection to our server. Check your signal and open the app again.')
      else ...[
        if (c.myName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  const TextSpan(text: 'You’re chatting as ', style: TextStyle(color: RaColors.muted)),
                  TextSpan(text: c.myName, style: const TextStyle(fontWeight: FontWeight.w700)),
                ])),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => askForName(context, change: true),
                child: const Text('Change'),
              ),
            ]),
          ),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () => startRoom(context),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New room', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: const BorderSide(color: RaColors.line2)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinRoomScreen())),
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('Join with a code', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SectionTitle('Your rooms'),
        if (!c.roomsLoaded)
          const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: CircularProgressIndicator(color: RaColors.gold)))
        else if (c.rooms.isEmpty)
          const EmptyNote('No rooms yet', 'Start one and send the link to your friends, or join theirs with the code they send you.')
        else
          Container(
            decoration: cardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: Column(children: [for (final r in c.rooms) RoomTile(room: r)]),
            ),
          ),
        const SizedBox(height: 14),
        const Text('Messages are deleted after 30 days. Long-press a message to report it or hide someone.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: RaColors.faint)),
      ],
    ]);
  }
}

class RoomTile extends StatelessWidget {
  const RoomTile({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final r = room;
    final unread = c.hasUnread(r);
    final last = r.lastText.isEmpty
        ? r.peopleLine(c.myUid ?? '')
        : c.blocked.contains(r.lastUid)
            ? 'Hidden message'
            : '${r.lastUid == c.myUid ? 'You' : r.lastName}: ${r.lastText}';
    return InkWell(
      onTap: () => openRoom(context, r.id),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: RaColors.line))),
        child: Row(children: [
          RoomAvatar(room: r),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (r.lastAt != null)
                  Text(chatTime(r.lastAt!), style: TextStyle(fontSize: 12, color: unread ? RaColors.gold : RaColors.faint)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(
                  child: Text(last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: unread ? RaColors.ink : RaColors.faint, fontWeight: unread ? FontWeight.w600 : null)),
                ),
                if (unread)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(color: RaColors.gold, shape: BoxShape.circle),
                  ),
              ]),
              if (r.match != null) ...[
                const SizedBox(height: 3),
                Text('Watching ${matchTitle(c, r.match!)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: RaColors.goldSoft)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Asks for your chat name if you haven't picked one. True when you have one.
Future<bool> askForName(BuildContext context, {bool change = false}) async {
  final c = AppScope.read(context);
  if (c.myName != null && !change) return true;
  final name = await showDialog<String>(context: context, builder: (_) => _NameDialog(initial: c.myName ?? ''));
  if (name == null) return c.myName != null;
  await c.setMyName(name);
  return c.myName != null;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() {
    final n = cleanName(_text.text);
    if (n != null) Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: RaColors.card,
      title: const Text('Your name in chat'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your friends see this next to your messages. A first name or nickname is fine.',
            style: TextStyle(color: RaColors.muted, fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          autofocus: true,
          maxLength: maxNameLength,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Brendon', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _done(),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: cleanName(_text.text) == null ? null : _done, child: const Text('Save')),
      ],
    );
  }
}

/// New room: asks for your name (first time) and the room's name, makes it, opens it and shows the invite.
Future<void> startRoom(BuildContext context, {PinnedMatch? match}) async {
  if (!await askForName(context) || !context.mounted) return;
  final c = AppScope.read(context);
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _RoomNameDialog(initial: match == null ? 'Rugby chat' : matchTitle(c, match), title: 'New room'),
  );
  if (name == null || !context.mounted) return;
  try {
    final r = await c.createRoom(name, match: match);
    if (!context.mounted) return;
    await openRoom(context, r.id, invite: true);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t make the room. Check your connection and try again.')));
    }
  }
}

Future<String?> askRoomName(BuildContext context, String current) =>
    showDialog<String>(context: context, builder: (_) => _RoomNameDialog(initial: current, title: 'Rename room'));

class _RoomNameDialog extends StatefulWidget {
  const _RoomNameDialog({required this.initial, required this.title});

  final String initial;
  final String title;

  @override
  State<_RoomNameDialog> createState() => _RoomNameDialogState();
}

class _RoomNameDialogState extends State<_RoomNameDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _ok => _text.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: RaColors.card,
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: maxRoomNameLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Room name', border: OutlineInputBorder()),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _ok ? Navigator.of(context).pop(_text.text.trim()) : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _ok ? () => Navigator.of(context).pop(_text.text.trim()) : null, child: const Text('OK')),
      ],
    );
  }
}

/// Join a room: type or paste the code (or the whole invite). An invite link opens this with the code filled in.
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  late final _text = TextEditingController(text: widget.initialCode == null ? '' : spacedCode(widget.initialCode!));
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = parseRoomCode(_text.text);
    if (code == null) {
      setState(() => _error = 'That doesn’t look like a room code. It’s 12 letters and numbers, like ABCD-EFGH-JKMN.');
      return;
    }
    final c = AppScope.read(context);
    if (!c.chatAvailable) {
      setState(() => _error = 'Chat needs a connection to our server. Check your signal and try again.');
      return;
    }
    if (!await askForName(context) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await c.joinRoom(code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RoomScreen(id: r.id)));
    } on ChatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a room')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        const Text('Enter the code from your friend’s invite, or paste the whole message.', style: TextStyle(color: RaColors.muted)),
        const SizedBox(height: 14),
        TextField(
          controller: _text,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          style: displayStyle(20),
          decoration: InputDecoration(hintText: 'ABCD-EFGH-JKMN', border: const OutlineInputBorder(), errorText: _error, errorMaxLines: 3),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          onPressed: _busy ? null : _join,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: RaColors.onGold))
              : const Text('Join', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
