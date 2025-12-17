import 'package:flutter/material.dart';

/// 공통 컬러 토큰
const kInk = Color(0xFF0B1220);
const kMuted = Color(0xFF6B7280);
const kCard = Color(0xFFF7F8FA);
const kStroke = Color(0xFFE6E8EB);
const kBrand = Color(0xFF1E3A8A);
const kUp = Color(0xFF155E75);
const kDown = Color(0xFFE11D48);

// 오늘의 하이라이트 섹션 전체를 살짝 강조해 줄 배경 (필요하면 재사용)
const kHighlightBg = Color(0xFFF1F4FF);

/// 섹션 구분선
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, this.top = 16, this.bottom = 8});
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
      child: Container(height: 1, color: kStroke),
    );
  }
}
