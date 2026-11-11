import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/feeds.dart';
import '../models/share_card.dart';
import '../models/site_links.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import 'common.dart';

/// The pick (or, after the game, the score) as a picture in the style of the posts: cream paper,
/// navy ink, gold for the pick and grey for the other side, home on the left. 4:5, like a feed post.
class PickShareCard extends StatelessWidget {
  const PickShareCard({super.key, required this.gender, this.fixture, this.result, this.zone});

  final Gender gender;
  final Fixture? fixture;
  final Result? result;
  final String? zone; // tests pass one; otherwise the phone's own

  @override
  Widget build(BuildContext context) {
    final feed = AppScope.of(context).matchday!;
    final t = shareCardText(gender, fixture: fixture, result: result, zone: zone);
    final home = fixture?.home ?? result!.home, away = fixture?.away ?? result!.away;
    final chance = fixture?.pick; // the home side's chance
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: LayoutBuilder(builder: (context, box) {
        final u = box.maxWidth / 360; // everything scales with the card, so the picture looks the same at any size
        TextStyle word(double size, {Color color = RaColors.onGold, FontWeight weight = FontWeight.w600}) =>
            TextStyle(fontFamily: body, fontSize: size * u, color: color, fontWeight: weight, height: 1.25);
        return Container(
          color: RaColors.paper,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              color: RaColors.onGold,
              padding: EdgeInsets.symmetric(horizontal: 18 * u, vertical: 10 * u),
              child: Row(children: [
                Expanded(child: Text(t.when.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: word(9.5, color: RaColors.paper, weight: FontWeight.w700).copyWith(letterSpacing: 1.2 * u))),
                SizedBox(width: 8 * u),
                TeamBadge(feed.nation(home), size: 18 * u),
                SizedBox(width: 4 * u),
                TeamBadge(feed.nation(away), size: 18 * u),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22 * u, 18 * u, 22 * u, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 18 * u, height: 2.5 * u, color: RaColors.goldInk),
                    SizedBox(width: 8 * u),
                    Flexible(child: Text(t.kicker, maxLines: 1, overflow: TextOverflow.ellipsis, style: word(10, color: RaColors.goldInk, weight: FontWeight.w800).copyWith(letterSpacing: 1.6 * u))),
                  ]),
                  SizedBox(height: 10 * u),
                  Text(t.matchup, maxLines: 1, overflow: TextOverflow.ellipsis, style: word(14, color: RaColors.paperMuted)),
                  SizedBox(height: 4 * u),
                  SizedBox(height: 6 * u),
                  Text(t.headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: displayStyle(42 * u, color: RaColors.onGold, weight: FontWeight.w800).copyWith(height: 1.05)),
                  if (t.figure != null)
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(t.figure!, style: displayStyle(104 * u, color: RaColors.goldInk, weight: FontWeight.w800).copyWith(height: 1.1))),
                  const Spacer(),
                  if (chance != null && result == null) ...[
                    _Bar(home: home, away: away, homeChance: chance, u: u),
                    SizedBox(height: 6 * u),
                    Text('Gold is the model’s pick. Home side on the left.', style: word(9.5, color: RaColors.paperMuted, weight: FontWeight.w500)),
                  ],
                  SizedBox(height: 14 * u),
                ]),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(22 * u, 10 * u, 22 * u, 14 * u),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: RaColors.onGold.withValues(alpha: 0.12)))),
              child: Row(children: [
                BrandMark(size: 22 * u),
                SizedBox(width: 8 * u),
                Text('RugbyAnalysis.com', style: displayStyle(14 * u, color: RaColors.onGold)),
                SizedBox(width: 8 * u),
                Expanded(
                  child: Text('@rugby_analysis_stats',
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: word(10, color: RaColors.paperMuted, weight: FontWeight.w500)),
                ),
              ]),
            ),
          ]),
        );
      }),
    );
  }
}

/// The pick bar as on the posts: home on the left, gold for the pick, grey for the other side, the
/// chances written at each end.
class _Bar extends StatelessWidget {
  const _Bar({required this.home, required this.away, required this.homeChance, required this.u});

  final String home, away;
  final double homeChance;
  final double u;

  @override
  Widget build(BuildContext context) {
    final h = (homeChance * 100).round().clamp(1, 99), homePick = homeChance >= 0.5;
    TextStyle s(bool pick) =>
        TextStyle(fontFamily: body, fontSize: 11 * u, fontWeight: pick ? FontWeight.w800 : FontWeight.w600, color: pick ? RaColors.onGold : RaColors.paperMuted);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('$home $h%', maxLines: 1, overflow: TextOverflow.ellipsis, style: s(homePick))),
        const SizedBox(width: 8),
        Expanded(child: Text('${100 - h}% $away', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: s(!homePick))),
      ]),
      SizedBox(height: 5 * u),
      ClipRRect(
        borderRadius: BorderRadius.circular(4 * u),
        child: SizedBox(
          height: 10 * u,
          child: Row(children: [
            Expanded(flex: h, child: Container(color: homePick ? RaColors.gold : RaColors.greyBar)),
            SizedBox(width: 2 * u),
            Expanded(flex: 100 - h, child: Container(color: homePick ? RaColors.greyBar : RaColors.gold)),
          ]),
        ),
      ),
    ]);
  }
}

/// The Share button's sheet: the card as it will look, then "Share picture" (the card plus the text and
/// link) or "Share as text" (text and link only).
Future<void> showShareSheet(BuildContext context, {required Gender gender, Fixture? fixture, Result? result}) {
  final key = GlobalKey();
  final text = shareText(gender, fixture: fixture, result: result);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RaColors.card,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(result != null ? 'Share the score' : 'Share the pick', style: displayStyle(18)),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RepaintBoundary(key: key, child: PickShareCard(gender: gender, fixture: fixture, result: result)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () async {
              final png = await cardPng(key);
              if (png == null) return;
              await SharePlus.instance.share(ShareParams(
                files: [XFile.fromData(png, mimeType: 'image/png', name: 'rugbyanalysis-pick.png')],
                text: text,
              ));
            },
            icon: const Icon(Icons.image_outlined),
            label: const Text('Share picture'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => SharePlus.instance.share(ShareParams(text: text)),
            icon: const Icon(Icons.short_text),
            label: const Text('Share as text'),
          ),
        ]),
      ),
    ),
  );
}

/// The card drawn at 1080 pixels wide, as a PNG.
Future<Uint8List?> cardPng(GlobalKey key) async {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderRepaintBoundary) return null;
  final image = await box.toImage(pixelRatio: 1080 / box.size.width);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
