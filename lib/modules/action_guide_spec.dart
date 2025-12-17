
class ActionGuideSpec {
  static const String moduleId = "action_guide_v1";
  static const String title = "행동 가이드";

  static Map<String, dynamic> jsonShape() {
    return {
      "module_id": moduleId,
      "title": title,
      "action": "enter|wait|avoid",
      "badge": "green|yellow|red",
      "headline": "string", // 한 줄 결론 (초보용)
      "why": ["string"], // 5모듈 근거 요약 (3~6개)
      "dont": ["string"], // 하지 말아야 할 행동 (2~5개)
      "if_then": [
        // 수익을 노린다면 '이 조건일 때만'
        {"if": "string", "then": "string"}
      ],
      "risk_controls": [
        // 손해 방지(리스크 관리) - 초보에게 진짜 중요
        "string"
      ],
      "confidence": 0.0, // 0.0~1.0
      "disclaimer": "string"
    };
  }
}
