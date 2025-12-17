import 'dart:core';

/// ===============================
/// 검색 결과 모델
/// ===============================
class SearchResult {
  final String symbol;
  final String description;
  final String exchange;

  const SearchResult({
    required this.symbol,
    required this.description,
    required this.exchange,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) {
    return SearchResult(
      symbol: (j['symbol'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      exchange: (j['exchange'] ?? j['type'] ?? '').toString(),
    );
  }
}

/// ===============================
/// 캔들 데이터 (차트/기술모듈 공용)
/// ===============================
class Candle {
  final DateTime t;
  final double o;
  final double h;
  final double l;
  final double c;
  final double v;

  Candle(this.t, this.o, this.h, this.l, this.c, this.v);
}

/* ============================================================
   기술 2모듈 (변동성 · 전문가 해석) 전용 데이터 모델
   ============================================================ */

class ExpertSummary {
  final String grade; // A ~ D
  final String label;
  final String emoji;
  final String oneLine;

  ExpertSummary({
    required this.grade,
    required this.label,
    required this.emoji,
    required this.oneLine,
  });

  factory ExpertSummary.fromJson(Map<String, dynamic> json) {
    return ExpertSummary(
      grade: json['grade'] as String? ?? '-',
      label: json['label'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '📊',
      oneLine: json['one_line'] as String? ?? '',
    );
  }
}

class ExpertInsights {
  final String patternView;
  final String momentumView;
  final String liquidityView;
  final String riskView;

  ExpertInsights({
    required this.patternView,
    required this.momentumView,
    required this.liquidityView,
    required this.riskView,
  });

  factory ExpertInsights.fromJson(Map<String, dynamic> json) {
    return ExpertInsights(
      patternView: json['pattern_view'] as String? ?? '',
      momentumView: json['momentum_view'] as String? ?? '',
      liquidityView: json['liquidity_view'] as String? ?? '',
      riskView: json['risk_view'] as String? ?? '',
    );
  }
}

class ExpertActionAdvice {
  final String shortTerm;
  final String midTerm;
  final String avoid;

  ExpertActionAdvice({
    required this.shortTerm,
    required this.midTerm,
    required this.avoid,
  });

  factory ExpertActionAdvice.fromJson(Map<String, dynamic> json) {
    return ExpertActionAdvice(
      shortTerm: json['short_term'] as String? ?? '',
      midTerm: json['mid_term'] as String? ?? '',
      avoid: json['avoid'] as String? ?? '',
    );
  }
}

class Tech2ExpertModule {
  final String moduleId;
  final String moduleType;
  final String title;
  final ExpertSummary summary;
  final ExpertInsights expertInsights;
  final ExpertActionAdvice actionAdvice;
  final String aiFinalComment;

  Tech2ExpertModule({
    required this.moduleId,
    required this.moduleType,
    required this.title,
    required this.summary,
    required this.expertInsights,
    required this.actionAdvice,
    required this.aiFinalComment,
  });

  factory Tech2ExpertModule.fromJson(Map<String, dynamic> json) {
    return Tech2ExpertModule(
      moduleId: json['module_id'] as String? ?? '',
      moduleType: json['module_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: ExpertSummary.fromJson(
        (json['summary'] as Map<String, dynamic>? ?? const {}),
      ),
      expertInsights: ExpertInsights.fromJson(
        (json['expert_insights'] as Map<String, dynamic>? ?? const {}),
      ),
      actionAdvice: ExpertActionAdvice.fromJson(
        (json['action_advice'] as Map<String, dynamic>? ?? const {}),
      ),
      aiFinalComment: json['ai_final_comment'] as String? ?? '',
    );
  }
}
