// TEMPORARY (review only, removed before merge): renders the new Clubs and Chat screens from test/data (build 114).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rugby_analysis/main.dart';
import 'package:rugby_analysis/models/chat.dart';
import 'package:rugby_analysis/models/feeds.dart';
import 'package:rugby_analysis/screens/club_screen.dart';
import 'package:rugby_analysis/screens/clubs_screen.dart';
import 'package:rugby_analysis/screens/room_screen.dart';
import 'package:rugby_analysis/services/chat_service.dart';
import 'package:rugby_analysis/services/feed_service.dart';
import 'package:rugby_analysis/state/app_controller.dart';
import 'package:rugby_analysis/widgets/chat_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files.where((f) => File(f).existsSync())) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

class _Feeds implements FeedSource {
  @override
  Future<Map<String, dynamic>> load(String name) async => jsonDecode(File('test/data/$name.json').readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  setUpAll(() async {
    await _font('Poppins', ['assets/fonts/Poppins-SemiBold.ttf', 'assets/fonts/Poppins-Bold.ttf', 'assets/fonts/Poppins-ExtraBold.ttf']);
    final fig = ['assets/fonts/Figtree-Regular.ttf', 'assets/fonts/Figtree-Medium.ttf', 'assets/fonts/Figtree-SemiBold.ttf', 'assets/fonts/Figtree-Bold.ttf'];
    await _font('Figtree', fig);
    await _font('Roboto', fig);
    await _font('Noto Color Emoji', ['tool/fonts/NotoColorEmoji.ttf']);
    final fonts = Directory('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts');
    await _font('MaterialIcons', fonts.existsSync() ? [for (final f in fonts.listSync().whereType<File>()) if (f.path.toLowerCase().endsWith('materialicons-regular.otf')) f.path] : []);
  });

  Future<AppController> start(WidgetTester tester, {bool tall = true}) async {
    tester.view.physicalSize = Size(1080, tall ? 3600 : 2340);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final chat = MemoryChat();
    final md = jsonDecode(File('test/data/matchday.json').readAsStringSync()) as Map<String, dynamic>;
    final side = MatchdayFeed.fromJson(md).men;
    final f = side.fixtures.isNotEmpty ? side.fixtures.first : null;
    chat.seed(
      Room(
        id: 'ABCDEFGHJKMN',
        name: 'Saturday rugby',
        ownerUid: 'me',
        members: const ['me', 'tom', 'sipho', 'ana'],
        names: const {'me': 'Brendon', 'tom': 'Tom', 'sipho': 'Sipho', 'ana': 'Ana'},
        match: f == null ? null : PinnedMatch.test(Gender.men, f),
        lastAt: now.subtract(const Duration(minutes: 2)),
        lastText: 'That scrum though 😳',
        lastName: 'Sipho',
        lastUid: 'sipho',
      ),
      [
        ChatMessage(id: '1', uid: 'tom', name: 'Tom', text: 'Who’s watching tonight?', at: now.subtract(const Duration(minutes: 50))),
        ChatMessage(id: '2', uid: 'me', name: 'Brendon', text: 'Me! Model gives us 59% 🇿🇦', at: now.subtract(const Duration(minutes: 48))),
        ChatMessage(id: '3', uid: 'ana', name: 'Ana', text: 'Pub or sofa?', at: now.subtract(const Duration(minutes: 30))),
        ChatMessage(id: '4', uid: 'ana', name: 'Ana', text: 'I vote sofa, it’s raining', at: now.subtract(const Duration(minutes: 29))),
        ChatMessage(id: '5', uid: 'sipho', name: 'Sipho', text: 'That scrum though 😳', at: now.subtract(const Duration(minutes: 2))),
      ],
    );
    chat.seed(Room(
      id: 'BCDEFGHJKMNP',
      name: 'Glasgow season tickets',
      ownerUid: 'tom',
      members: const ['me', 'tom'],
      names: const {'me': 'Brendon', 'tom': 'Tom'},
      lastAt: now.subtract(const Duration(days: 1, hours: 2)),
      lastText: 'See you at Scotstoun',
      lastName: 'Brendon',
      lastUid: 'me',
    ));
    final c = AppController(source: _Feeds(), chat: chat);
    await tester.pumpWidget(RugbyApp(controller: c));
    await c.start();
    c.myName = 'Brendon';
    c.toggleClub('glasgow');
    c.toggleClub('stormers');
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> shot(WidgetTester tester, String name) =>
      expectLater(find.byType(MaterialApp), matchesGoldenFile('review/$name.png'));

  testWidgets('clubs', (tester) async {
    final c = await start(tester);
    c.setTab(AppTab.clubs);
    await tester.pumpAndSettle();
    await shot(tester, 'clubs');
    await tester.drag(find.descendant(of: find.byType(ClubsScreen), matching: find.byType(Scrollable)).first, const Offset(0, -1250));
    await tester.pumpAndSettle();
    await shot(tester, 'clubs-2');
  });

  testWidgets('club', (tester) async {
    await start(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => const ClubScreen(id: 'glasgow')));
    await tester.pumpAndSettle();
    await shot(tester, 'club');
  });

  testWidgets('chat', (tester) async {
    final c = await start(tester, tall: false);
    c.setTab(AppTab.chat);
    await tester.pumpAndSettle();
    await shot(tester, 'chat');
  });

  testWidgets('room', (tester) async {
    await start(tester, tall: false);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => const RoomScreen(id: 'ABCDEFGHJKMN')));
    await tester.pumpAndSettle();
    await shot(tester, 'room');
  });

  testWidgets('invite', (tester) async {
    final c = await start(tester, tall: false);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => const RoomScreen(id: 'ABCDEFGHJKMN')));
    await tester.pumpAndSettle();
    showInvite(tester.element(find.byType(RoomScreen)), c.room('ABCDEFGHJKMN')!);
    await tester.pumpAndSettle();
    await shot(tester, 'invite');
  });

  testWidgets('pin a match', (tester) async {
    await start(tester, tall: false);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => const RoomScreen(id: 'BCDEFGHJKMNP')));
    await tester.pumpAndSettle();
    pickMatch(tester.element(find.byType(RoomScreen)));
    await tester.pumpAndSettle();
    await shot(tester, 'pin');
  });
}
