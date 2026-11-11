import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/feeds.dart';
import '../models/format.dart';
import '../theme.dart';

/// A team's mark: its flag in a circle of its colour, or its short code when
/// there's no flag (as on the website).
class TeamBadge extends StatelessWidget {
  const TeamBadge(this.nation, {super.key, this.size = 30});

  final Nation nation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final flag = nation.flag;
    return Semantics(
      label: nation.name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: nation.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
        child: flag.isNotEmpty
            ? Text(flag, style: TextStyle(fontSize: size * 0.55, height: 1, fontFamilyFallback: const ['Noto Color Emoji']))
            : Text(nation.code,
                style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: nation.onPrimary, height: 1)),
      ),
    );
  }
}

/// The RugbyAnalysis logo (site/logo/icon.svg): the gold ball on a navy rounded square.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Semantics(label: 'RugbyAnalysis', image: true, child: CustomPaint(size: Size.square(size), painter: const _BrandPainter()));
}

/// Draws the logo on its 64-unit grid, with the same shapes and numbers as the SVG.
class _BrandPainter extends CustomPainter {
  const _BrandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 64, 64), const Radius.circular(14)), Paint()..color = RaColors.onGold);
    canvas.translate(32, 32);
    canvas.rotate(-35 * 3.14159265 / 180); // rotate(-35 32 32)
    canvas.translate(-32, -32);
    final ball = Rect.fromCenter(center: const Offset(32, 32), width: 50, height: 30);
    canvas.drawOval(ball, Paint()..color = RaColors.gold);
    canvas.drawOval(ball, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = RaColors.onGold.withValues(alpha: 0.35));
    final seam = Paint()
      ..color = RaColors.onGold
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(20, 32), const Offset(44, 32), seam);
    seam.strokeWidth = 2.4;
    for (final x in [25.0, 30.0, 35.0, 40.0]) {
      canvas.drawLine(Offset(x, 28.5), Offset(x, 35.5), seam);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RaCard extends StatelessWidget {
  const RaCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.highlight = false, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: cardDecoration(color: highlight ? RaColors.cardHi : RaColors.card, border: highlight ? RaColors.gold : RaColors.line),
      padding: padding,
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: box),
    );
  }
}

/// A gold eyebrow and a section title, with an optional note on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.eyebrow, this.note});

  final String title;
  final String? eyebrow;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (eyebrow != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 22, height: 3, decoration: BoxDecoration(color: RaColors.gold, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text(eyebrow!.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: display, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.6, color: RaColors.gold)),
            ]),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text(title, style: displayStyle(18))),
          if (note != null) Text(note!, style: const TextStyle(fontSize: 12, color: RaColors.faint)),
        ]),
      ]),
    );
  }
}

/// A small rounded label: 'Live', 'Your team', 'Big game'.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? RaColors.gold : RaColors.track,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: strong ? RaColors.onGold : RaColors.ink)),
    );
  }
}

/// The model's pick as a bar. Gold is always the side the model picks and the other side is grey, the same
/// on the website and in the posts; the home side stays on the left.
class PickBar extends StatelessWidget {
  const PickBar({super.key, required this.home, required this.away, required this.homeChance});

  final String home;
  final String away;
  final double homeChance;

  @override
  Widget build(BuildContext context) {
    final p = pickOf(home, away, homeChance)!;
    return Semantics(
      label: 'Model pick: ${p.team}, ${p.pct}% chance of winning',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('Model pick ', style: TextStyle(fontSize: 11, color: RaColors.muted)),
          Text(p.team, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${p.pct}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(children: [
              Expanded(
                flex: (homeChance * 100).round().clamp(1, 99),
                child: Container(color: homeChance >= 0.5 ? RaColors.gold : RaColors.line2),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: (100 - (homeChance * 100).round()).clamp(1, 99),
                child: Container(color: homeChance >= 0.5 ? RaColors.line2 : RaColors.gold),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// A chance as a labelled bar: 'Semi-final ███░░ 56%'.
class ChanceBar extends StatelessWidget {
  const ChanceBar({super.key, required this.label, required this.value, this.scale = 100, this.leading});

  final String label;
  final double value; // %
  final double scale; // the value that fills the bar
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final fill = scale <= 0 ? 0.0 : (value / scale).clamp(0.0, 1.0);
    return Semantics(
      label: '$label: ${pct(value)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          SizedBox(width: leading == null ? 104 : 86, child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(value: fill == 0 ? 0 : fill.clamp(0.01, 1.0), minHeight: 10, color: RaColors.gold, backgroundColor: RaColors.track),
            ),
          ),
          SizedBox(width: 46, child: Text(pct(value), textAlign: TextAlign.right, style: const TextStyle(fontFamily: display, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}

/// Recent results as W / D / L squares, most recent on the right.
class FormDots extends StatelessWidget {
  const FormDots(this.form, {super.key});

  final String form;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Form, most recent last: ${form.split('').join(' ')}',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final r in form.split(''))
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(left: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: r == 'W' ? RaColors.gold : r == 'D' ? const Color(0xFF3A4A66) : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: r == 'L' ? Border.all(color: const Color(0xFF6C7C99), width: 1.5) : null,
            ),
            child: Text(r, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: r == 'W' ? RaColors.onGold : RaColors.ink)),
          ),
      ]),
    );
  }
}

/// Men / Women switch.
class GenderSwitch extends StatelessWidget {
  const GenderSwitch({super.key, required this.value, required this.onChanged});

  final Gender value;
  final ValueChanged<Gender> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Gender>(
      segments: [for (final g in Gender.values) ButtonSegment(value: g, label: Text(g.label))],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RaColors.ink : RaColors.card),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RaColors.onGold : RaColors.muted),
        side: const WidgetStatePropertyAll(BorderSide(color: RaColors.line2)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700, fontFamily: body)),
      ),
    );
  }
}

/// The empty state for a section: what's missing and why.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.title, this.body, {super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return RaCard(
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: RaColors.muted, fontSize: 13)),
      ]),
    );
  }
}

Future<void> openLink(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// A full-width button that opens the matching page on rugbyanalysis.com in the browser.
/// The website has the longer record (every Test back to the 1800s); the app keeps the recent picture.
class WebsiteButton extends StatelessWidget {
  const WebsiteButton({super.key, required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: const BorderSide(color: RaColors.line2)),
      onPressed: () => openLink(url),
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// The website and socials, at the bottom of every main tab.
class FooterLinks extends StatelessWidget {
  const FooterLinks({super.key});

  static const links = [
    (label: 'Website', sub: 'rugbyanalysis.com', url: 'https://rugbyanalysis.com', icon: Icons.public),
    (label: 'Instagram', sub: '@rugby_analysis_stats', url: 'https://www.instagram.com/rugby_analysis_stats/', icon: Icons.north_east),
    (label: 'Facebook', sub: 'Follow the page', url: 'https://www.facebook.com/profile.php?id=61595081338465', icon: Icons.north_east),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Column(children: [
        const Divider(),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const BrandMark(size: 22),
          const SizedBox(width: 8),
          Text('RugbyAnalysis.com', style: displayStyle(15)),
        ]),
        const SizedBox(height: 4),
        const Text('More stats, stories and match previews', style: TextStyle(fontSize: 12, color: RaColors.faint)),
        const SizedBox(height: 12),
        Row(children: [
          for (final l in links)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: RaCard(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  onTap: () => openLink(l.url),
                  child: Column(children: [
                    Icon(l.icon, size: 18, color: RaColors.gold),
                    const SizedBox(height: 4),
                    Text(l.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(l.sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: RaColors.muted)),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
