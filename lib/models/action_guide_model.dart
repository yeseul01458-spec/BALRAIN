

class IfThenRule {
  final String ifCond;
  final String thenDo;

  const IfThenRule({required this.ifCond, required this.thenDo});

  factory IfThenRule.fromJson(Map<String, dynamic> json) {
    String pick(dynamic v) => (v ?? '').toString().trim();
    return IfThenRule(
      ifCond: pick(json["if"] ?? json["if_cond"] ?? json["condition"]),
      thenDo: pick(json["then"] ?? json["then_do"] ?? json["action"]),
    );
  }

  Map<String, dynamic> toJson() => {"if": ifCond, "then": thenDo};
}

class ActionGuide {
  final String moduleId;
  final String title;

  /// enter|wait|avoid
  final String action;

  /// green|yellow|red
  final String badge;

  final String headline;
  final List<String> why;
  final List<String> dont;
  final List<IfThenRule> ifThen;
  final List<String> riskControls;

  /// 0.0 ~ 1.0
  final double confidence;

  final String disclaimer;

  const ActionGuide({
    required this.moduleId,
    required this.title,
    required this.action,
    required this.badge,
    required this.headline,
    required this.why,
    required this.dont,
    required this.ifThen,
    required this.riskControls,
    required this.confidence,
    required this.disclaimer,
  });

  // ---------- helpers ----------
  static String _s(Map<String, dynamic> j, String a, [String? b, String? c]) {
    final v = j[a] ?? (b == null ? null : j[b]) ?? (c == null ? null : j[c]);
    return (v ?? '').toString().trim();
  }

  static List<String> _listStr(dynamic v) {
    if (v is List) {
      return v.map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return <String>[];
  }

  static double _confidence01(dynamic v) {
    // 지원: 0~1, 0~100, "85" 등
    if (v is num) {
      final n = v.toDouble();
      if (n > 1.0) return (n / 100.0).clamp(0.0, 1.0);
      return n.clamp(0.0, 1.0);
    }
    final s = (v ?? '').toString().trim();
    final parsed = double.tryParse(s);
    if (parsed == null) return 0.5;
    if (parsed > 1.0) return (parsed / 100.0).clamp(0.0, 1.0);
    return parsed.clamp(0.0, 1.0);
  }

  static String _mapStanceToAction(String stance) {
    final t = stance.trim();
    // 서비스 옛 스키마(진입/관망/주의)
    if (t.contains('진입')) return 'enter';
    if (t.contains('관망')) return 'wait';
    if (t.contains('주의')) return 'avoid';
    // 혹시 영어로 올 때
    if (t.toLowerCase() == 'enter') return 'enter';
    if (t.toLowerCase() == 'wait') return 'wait';
    if (t.toLowerCase() == 'avoid') return 'avoid';
    return 'wait';
  }

  static String _badgeFromAction(String action) {
    switch (action) {
      case 'enter':
        return 'green';
      case 'avoid':
        return 'red';
      case 'wait':
      default:
        return 'yellow';
    }
  }

  factory ActionGuide.fromJson(Map<String, dynamic> json) {
    // ✅ 1) “정식 스키마” 우선 파싱
    final why = _listStr(json["why"]);
    final dont = _listStr(json["dont"]);
    final risk = _listStr(json["risk_controls"]);

    final ifThenRaw = (json["if_then"] is List) ? (json["if_then"] as List) : <dynamic>[];
    final ifThen = ifThenRaw
        .whereType<Map>()
        .map((e) => IfThenRule.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.ifCond.isNotEmpty || r.thenDo.isNotEmpty)
        .toList();

    final directAction = _s(json, "action");
    final directBadge = _s(json, "badge");

    // ✅ 2) “옛 스키마(stance/reasons/plan)”도 호환
    final stance = _s(json, "stance");
    final oneLine = _s(json, "one_line", "oneLine");
    final reasons = _listStr(json["reasons"]);
    final notes = _s(json, "notes");
    final plan = (json["plan"] is Map) ? Map<String, dynamic>.from(json["plan"]) : <String, dynamic>{};
    final planEntry = _s(plan, "entry");
    final planRisk = _s(plan, "risk");
    final planTarget = _s(plan, "target");

    final action = directAction.isNotEmpty ? directAction : _mapStanceToAction(stance);
    final badge = directBadge.isNotEmpty ? directBadge : _badgeFromAction(action);

    // why/riskControls/disclaimer/headline 보강
    final mergedWhy = (why.isNotEmpty ? why : reasons);
    final mergedRisk = (risk.isNotEmpty
        ? risk
        : _listStr(planRisk.isNotEmpty ? [planRisk] : null));

    // dont가 비면 “피해야 할 것”을 plan 기반으로라도 채우기
    final mergedDont = dont.isNotEmpty
        ? dont
        : <String>[
      if (planEntry.isNotEmpty) '진입은 이렇게: $planEntry',
      if (planTarget.isNotEmpty) '목표/익절은 이렇게: $planTarget',
    ].where((e) => e.isNotEmpty).toList();

    final headline = _s(json, "headline").isNotEmpty ? _s(json, "headline") : oneLine;
    final disclaimer = _s(json, "disclaimer").isNotEmpty ? _s(json, "disclaimer") : notes;

    return ActionGuide(
      moduleId: _s(json, "module_id", "moduleId").isNotEmpty ? _s(json, "module_id", "moduleId") : "action_guide",
      title: _s(json, "title").isNotEmpty ? _s(json, "title") : "AI 결론",
      action: action,
      badge: badge,
      headline: headline,
      why: mergedWhy,
      dont: mergedDont,
      ifThen: ifThen,
      riskControls: mergedRisk,
      confidence: _confidence01(json["confidence"]),
      disclaimer: disclaimer,
    );
  }
}
