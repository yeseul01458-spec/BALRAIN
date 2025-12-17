import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class StockTile extends StatelessWidget {
  const StockTile({
    super.key,
    required this.rank,
    required this.name,
    required this.symbol,
    this.subtitle,
    this.onTap,
    this.showDivider = true,
  });

  final int rank;
  final String name;
  final String symbol;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  // 랭크: 아주 은은한 캡슐
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7F5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kBrand,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 이름/설명/티커
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: kMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          symbol,
                          style: GoogleFonts.robotoMono(
                            fontSize: 11,
                            color: kMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(Icons.chevron_right, size: 18, color: kMuted),
                ],
              ),
            ),
          ),
          if (showDivider)
            const Divider(
              height: 1,
              thickness: 0.6,
              color: kStroke,
            ),
        ],
      ),
    );
  }
}
