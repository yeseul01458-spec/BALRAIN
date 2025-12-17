class Tech4RangeLevelModule {
  final Summary summary;
  final KeyLevels keyLevels;
  final MarketStructure marketStructure;
  final ActionAdvice actionAdvice;
  final String aiFinalComment;

  Tech4RangeLevelModule({
    required this.summary,
    required this.keyLevels,
    required this.marketStructure,
    required this.actionAdvice,
    required this.aiFinalComment,
  });

  factory Tech4RangeLevelModule.fromJson(Map<String, dynamic> json) {
    return Tech4RangeLevelModule(
      summary: Summary.fromJson(json['summary'] ?? {}),
      keyLevels: KeyLevels.fromJson(json['key_levels'] ?? {}),
      marketStructure: MarketStructure.fromJson(json['market_structure'] ?? {}),
      actionAdvice: ActionAdvice.fromJson(json['action_advice'] ?? {}),
      aiFinalComment: json['ai_final_comment'] ?? '',
    );
  }
}

class Summary {
  final String grade;
  final String label;
  final String emoji;
  final String oneLine;

  Summary({
    required this.grade,
    required this.label,
    required this.emoji,
    required this.oneLine,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      grade: json['grade'] ?? '',
      label: json['label'] ?? '',
      emoji: json['emoji'] ?? '🧱',
      oneLine: json['one_line'] ?? '',
    );
  }
}

class KeyLevels {
  final String support1;
  final String support2;
  final String resistance1;
  final String resistance2;

  KeyLevels({
    required this.support1,
    required this.support2,
    required this.resistance1,
    required this.resistance2,
  });

  factory KeyLevels.fromJson(Map<String, dynamic> json) {
    return KeyLevels(
      support1: json['support_1'] ?? '',
      support2: json['support_2'] ?? '',
      resistance1: json['resistance_1'] ?? '',
      resistance2: json['resistance_2'] ?? '',
    );
  }
}

class MarketStructure {
  final String rangeView;
  final String levelStory;
  final String trapRisk;

  MarketStructure({
    required this.rangeView,
    required this.levelStory,
    required this.trapRisk,
  });

  factory MarketStructure.fromJson(Map<String, dynamic> json) {
    return MarketStructure(
      rangeView: json['range_view'] ?? '',
      levelStory: json['level_story'] ?? '',
      trapRisk: json['trap_risk'] ?? '',
    );
  }
}

class ActionAdvice {
  final String entryPlan;
  final String stopPlan;
  final String targetPlan;
  final String avoid;

  ActionAdvice({
    required this.entryPlan,
    required this.stopPlan,
    required this.targetPlan,
    required this.avoid,
  });

  factory ActionAdvice.fromJson(Map<String, dynamic> json) {
    return ActionAdvice(
      entryPlan: json['entry_plan'] ?? '',
      stopPlan: json['stop_plan'] ?? '',
      targetPlan: json['target_plan'] ?? '',
      avoid: json['avoid'] ?? '',
    );
  }
}
