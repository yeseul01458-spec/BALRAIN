
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/action_guide_model.dart';

class ActionGuideCard extends StatelessWidget {
  final ActionGuide guide;
  const ActionGuideCard({super.key, required this.guide});

  // ✅ withOpacity 경고 회피용 (0.0 ~ 1.0)
  Color _alpha(Color c, double a) {
    final v = (a * 255).round().clamp(0, 255);
    return c.withAlpha(v);
  }

  Color _badgeColor() {
    switch (guide.badge) {
      case "green":
        return const Color(0xFF16A34A);
      case "red":
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _badgeText() {
    switch (guide.action) {
      case "enter":
        return "진입 고려 가능";
      case "avoid":
        return "회피 권장";
      default:
        return "관망이 유리";
    }
  }

  TextStyle _t({
    double size = 12,
    FontWeight weight = FontWeight.w600,
    Color color = const Color(0xFF111827),
    double? height,
  }) {
    return GoogleFonts.notoSansKr(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badgeColor();

    Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        t,
        style: _t(size: 13, weight: FontWeight.w800),
      ),
    );

    Widget bulletList(List<String> items) {
      if (items.isEmpty) {
        return Text('—', style: _t(size: 12.5, color: const Color(0xFF6B7280)));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.take(6).map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("•  ", style: _t(size: 12.8, color: const Color(0xFF374151), height: 1.35)),
                Expanded(
                  child: Text(
                    e,
                    style: _t(size: 12.8, color: const Color(0xFF374151), height: 1.35),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    final confidencePct = ((guide.confidence).clamp(0.0, 1.0) * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _alpha(badge, 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _alpha(badge, 0.25)),
                ),
                child: Text(
                  _badgeText(),
                  style: _t(size: 12.5, weight: FontWeight.w800, color: badge),
                ),
              ),
              const Spacer(),
              Text(
                '신뢰도 $confidencePct%',
                style: _t(size: 12, color: const Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            guide.headline.isEmpty ? '결론을 생성하지 못했습니다.' : guide.headline,
            style: _t(size: 16, weight: FontWeight.w900, height: 1.25),
          ),

          sectionTitle("왜 이렇게 판단했나"),
          bulletList(guide.why),

          sectionTitle("지금 하지 말아야 할 것"),
          bulletList(guide.dont),

          sectionTitle("수익을 노린다면 ‘이 조건일 때만’"),
          if (guide.ifThen.isEmpty)
            Text('—', style: _t(size: 12.5, color: const Color(0xFF6B7280)))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: guide.ifThen.take(4).map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichText(
                    text: TextSpan(
                      style: _t(size: 12.8, color: const Color(0xFF374151), height: 1.35),
                      children: [
                        const TextSpan(text: "•  IF "),
                        TextSpan(
                          text: r.ifCond,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(text: "  →  THEN "),
                        TextSpan(
                          text: r.thenDo,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          sectionTitle("손해 방지 규칙"),
          bulletList(guide.riskControls),

          const SizedBox(height: 8),
          Text(
            guide.disclaimer,
            style: _t(size: 11.5, color: const Color(0xFF9CA3AF), height: 1.35),
          ),
        ],
      ),
    );
  }
}
