import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// TickerScreen에 있는 ExpertModule 모델을 그대로 쓰는 방식이 제일 안전함.
/// 그래서 여기서는 반환 타입을 dynamic으로 두고, TickerScreen에서 ExpertModule.fromJson(...)로 파싱해도 됨.
/// (원하면 여기서 ExpertModule import 해서 바로 반환해도 되는데, 순환참조 위험이 있어서 안전하게 둠)
class AiRangeService {
  static final _geminiKey = const String.fromEnvironment('GEMINI_API_KEY');

  static Future<Map<String, dynamic>> analyzeRange({
    required String rangeSummary,
  }) async {
    if (_geminiKey.isEmpty) {
      throw Exception(
        kDebugMode
            ? 'GEMINI_API_KEY가 설정되지 않았습니다.\nflutter run --dart-define=GEMINI_API_KEY=... 로 실행해 주세요.'
            : 'AI 서버 설정이 아직 완료되지 않았어요.',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$_geminiKey',
    );

    final body = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": """
너는 '밸레인(BALRAIN)' 앱의 기술 4모듈, '레인지·레벨(지지/저항) 모듈' 전담 AI다.

- 아래 range_summary를 보고, 현재 가격이 박스/추세 전환/돌파·이탈 중 어디에 가까운지,
  핵심 레벨(지지/저항)과 갭, 전고/전저 테스트 관점으로 해석해라.
- 반드시 한국어만 사용한다.
- 과도한 단정은 피하고, "가능성이 높다", "다만 ~라면 조심" 같은 톤을 유지한다.
- 아래 JSON 스키마 **그대로**를 출력하고, JSON 이외 문장은 절대 쓰지 마라.

{
  "module_id": "tech_4_range_level",
  "module_type": "technical",
  "title": "기술 4모듈 · 레인지·레벨",
  "summary": {
    "grade": "A | B | C | D 중 하나",
    "label": "레인지·레벨 관점 한 줄 제목",
    "emoji": "🧱, 📦, ⚠️ 등 한 글자 이모지",
    "one_line": "현재 레벨/박스/돌파·이탈 상태를 한 줄로 요약"
  },
  "expert_insights": {
    "pattern_view": "박스/돌파/이탈/재시험(리테스트) 등 위치·패턴 관점",
    "momentum_view": "레벨 부근에서 힘이 붙는지/죽는지(속도·탄력) 해석",
    "liquidity_view": "레벨 구간에서 거래가 붙는지(참여 강도) 해석 (과도추정 금지)",
    "risk_view": "손절 기준(어느 레벨 이탈 시 위험), 손익비 관점 리스크 평가"
  },
  "action_advice": {
    "short_term": "단기/트레이딩 관점에서의 구체적 행동 가이드",
    "mid_term": "스윙/중기 관점에서의 전략",
    "avoid": "지금 피해야 할 진입·추매·손절 방식 등"
  },
  "ai_final_comment": "전체 레인지·레벨을 한 번 정리해 주는 총평 한 단락"
}
"""
            },
            {
              "text": "아래는 이 종목의 레인지·레벨 요약입니다:\n$rangeSummary"
            }
          ],
        }
      ],
      "generationConfig": {"responseMimeType": "application/json"}
    };

    final res = await http
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null ||
        candidates.isEmpty ||
        candidates[0]['content'] == null ||
        candidates[0]['content']['parts'] == null ||
        (candidates[0]['content']['parts'] as List).isEmpty) {
      throw Exception('Gemini 응답이 비어 있습니다.');
    }

    final text = candidates[0]['content']['parts'][0]['text'] as String? ?? '';
    if (text.isEmpty) throw Exception('Gemini 텍스트 응답이 없습니다.');

    final moduleJson = jsonDecode(text) as Map<String, dynamic>;
    return moduleJson;
  }
}
