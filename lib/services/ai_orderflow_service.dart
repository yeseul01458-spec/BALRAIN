import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// ✅ 모듈5: 호가·체결 흐름 (Gemini JSON 응답)
class AiOrderflowService {
  static const String _model =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent';

  static Future<Map<String, dynamic>> analyzeOrderflowJson({
    required String geminiKey,
    required String orderflowSummary,
  }) async {
    if (geminiKey.isEmpty) {
      throw Exception(kDebugMode
          ? 'GEMINI_API_KEY 미설정'
          : 'AI 서버 설정이 아직 완료되지 않았어요.');
    }

    final uri = Uri.parse('$_model?key=$geminiKey');

    final body = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": """
너는 '밸레인(BALRAIN)' 앱의 기술 5모듈, '호가·체결 흐름(오더플로우) 모듈' 전담 AI다.

- 아래 orderflow_summary를 보고,
  (1) 스프레드/체결 집중/거래대금이 말해주는 “진입 난이도”
  (2) 휩쏘/미끄러짐(슬리피지) 위험
  (3) 단기 체결 흐름이 추세를 밀어주는지/막는지
  를 조건부로 해석해라.
- 반드시 한국어만 사용한다.
- 과도한 단정은 피하고, “가능성/다만/만약” 톤을 유지한다.
- 아래 JSON 스키마 **그대로** 출력하고 JSON 이외 문장은 절대 쓰지 마라.

{
  "module_id": "tech_5_orderflow_tape",
  "module_type": "technical",
  "title": "기술 5모듈 · 호가·체결 흐름",
  "summary": {
    "grade": "A | B | C | D 중 하나",
    "label": "호가·체결 관점 한 줄 제목",
    "emoji": "⚡, 🧊, 🧨, 🧲 등 한 글자 이모지",
    "one_line": "지금 시장 체결/호가의 난이도를 한 줄로 요약"
  },
  "orderflow_metrics": {
    "spread_view": "스프레드/체결비용 관점(짧게)",
    "volume_concentration": "거래 집중/쏠림(짧게)",
    "slippage_risk": "슬리피지/휩쏘 위험(짧게)",
    "tape_tone": "체결 톤(매수우위/매도우위/혼조)을 한 문장",
    "execution_note": "초보가 실수하기 쉬운 실행(주문) 포인트"
  },
  "expert_insights": {
    "microstructure_view": "호가/체결 흐름이 의미하는 바(간단히)",
    "trend_support_view": "이 흐름이 추세를 돕는지/막는지",
    "trap_view": "가짜 움직임/낚시(함정) 시나리오"
  },
  "action_advice": {
    "entry_plan": "진입 시 유리한 주문 방식/타이밍(예: 분할/지정가/돌파 확인 등)",
    "risk_plan": "리스크 관리(손절·주문·체결 관리 포인트)",
    "avoid": "지금 피해야 할 매매/주문 습관"
  },
  "ai_final_comment": "전체 호가·체결 흐름을 정리한 총평 한 단락"
}
"""
            },
            {"text": "아래는 orderflow_summary입니다:\n$orderflowSummary"}
          ]
        }
      ],
      "generationConfig": {"responseMimeType": "application/json"}
    };

    final res = await http
        .post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body))
        .timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    final text = (candidates != null &&
        candidates.isNotEmpty &&
        candidates[0]['content']?['parts'] != null &&
        (candidates[0]['content']['parts'] as List).isNotEmpty)
        ? (candidates[0]['content']['parts'][0]['text'] as String? ?? '')
        : '';

    if (text.trim().isEmpty) {
      throw Exception('Gemini 응답이 비어 있습니다.');
    }

    final moduleJson = jsonDecode(text) as Map<String, dynamic>;
    return moduleJson;
  }

  /// (옵션) 숫자 안전 포맷 도우미
  static String pct(double v, {int d = 2}) {
    if (v.isNaN || v.isInfinite) return '0.00%';
    return '${v.toStringAsFixed(d)}%';
  }

  static double clamp(double v, double lo, double hi) =>
      math.min(hi, math.max(lo, v));
}
