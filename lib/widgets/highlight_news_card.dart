import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_item.dart';
import '../theme/app_colors.dart';

class HighlightNewsCard extends StatelessWidget {
  final NewsItem item;
  final int? rank; //
  final VoidCallback? onTapOverride;

  const HighlightNewsCard({
    super.key,
    required this.item,
    this.rank,
    this.onTapOverride,
  });

  Future<void> _openUrl(BuildContext context) async {
    final url = item.url.trim();
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = item.headline.trim().isEmpty ? '(제목 없음)' : item.headline.trim();
    final source = item.source.trim();
    final timeText = DateFormat('M/d HH:mm').format(item.datetime);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTapOverride ?? () => _openUrl(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ 랭크
              if (rank != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kBrand.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$rank',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kBrand,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // ✅ 본문
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ✅ 얇은 선
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.black.withOpacity(0.06),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        if (source.isNotEmpty)
                          Flexible(
                            child: Text(
                              source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kMuted,
                              ),
                            ),
                          ),
                        if (source.isNotEmpty) const SizedBox(width: 6),
                        Text(
                          timeText,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 11,
                            color: kMuted,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ✅ 썸네일
              if ((item.imageUrl ?? '').trim().isNotEmpty) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    item.imageUrl!.trim(),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: const Color(0xFFF3F4F6),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.newspaper_rounded,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
