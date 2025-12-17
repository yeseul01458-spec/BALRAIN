// lib/modules/technical/tech2_expert_view.dart

import 'package:flutter/material.dart';
import '../../models/tech2_expert_model.dart';

class Tech2ExpertView extends StatelessWidget {
  final Tech2ExpertModule data;

  const Tech2ExpertView({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1) 상단 요약
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.summary.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.summary.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.summary.oneLine,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: theme.colorScheme.primary.withOpacity(0.06),
                ),
                child: Text(
                  '등급 ${data.summary.grade}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2) 전문가 인사이트 섹션
          _SectionTitle('전문가 인사이트', theme),
          const SizedBox(height: 8),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InsightCard(
                title: '패턴 관점',
                body: data.expertInsights.patternView,
                icon: Icons.timeline,
              ),
              _InsightCard(
                title: '모멘텀 관점',
                body: data.expertInsights.momentumView,
                icon: Icons.speed,
              ),
              _InsightCard(
                title: '유동성 관점',
                body: data.expertInsights.liquidityView,
                icon: Icons.water_drop_outlined,
              ),
              _InsightCard(
                title: '리스크 관점',
                body: data.expertInsights.riskView,
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3) 행동 전략 가이드
          _SectionTitle('행동 전략 가이드', theme),
          const SizedBox(height: 8),

          _AdviceCard(
            label: '단기 / 트레이딩',
            body: data.actionAdvice.shortTerm,
            icon: Icons.flash_on,
          ),
          const SizedBox(height: 8),
          _AdviceCard(
            label: '중기 / 스윙',
            body: data.actionAdvice.midTerm,
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 8),
          _AdviceCard(
            label: '피해야 할 행동',
            body: data.actionAdvice.avoid,
            icon: Icons.block,
          ),

          const SizedBox(height: 24),

          // 4) AI 최종 코멘트
          _SectionTitle('AI 전문가 총평', theme),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.primary.withOpacity(0.04),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.aiFinalComment,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _SectionTitle(String text, ThemeData theme) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.grey[900],
      ),
    );
  }
}

/// 인사이트 카드 (패턴 / 모멘텀 / 유동성 / 리스크)
class _InsightCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _InsightCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 180,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                body,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[800],
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 행동 전략 카드 (단기 / 중기 / 피해야 할 행동)
class _AdviceCard extends StatelessWidget {
  final String label;
  final String body;
  final IconData icon;

  const _AdviceCard({
    required this.label,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
