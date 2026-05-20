import 'package:flutter/material.dart';

import '../theme/nova_theme.dart';

enum AppNoticeType { success, warning, error, info }

class AppNotice {
  static void show(
    BuildContext context,
    String message, {
    AppNoticeType type = AppNoticeType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = _scheme(type);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          content: Align(
            alignment: Alignment.bottomRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(scheme.icon, size: 18, color: scheme.fg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: scheme.fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

  static _NoticeScheme _scheme(AppNoticeType type) {
    switch (type) {
      case AppNoticeType.success:
        return const _NoticeScheme(
          bg: Color(0xFFE8F5E9),
          fg: Color(0xFF1B5E20),
          border: Color(0xFFA5D6A7),
          icon: Icons.check_circle_outline,
        );
      case AppNoticeType.warning:
        return const _NoticeScheme(
          bg: Color(0xFFFFF3E0),
          fg: Color(0xFFE65100),
          border: Color(0xFFFFCC80),
          icon: Icons.warning_amber_rounded,
        );
      case AppNoticeType.error:
        return const _NoticeScheme(
          bg: Color(0xFFFFEBEE),
          fg: Color(0xFFB71C1C),
          border: Color(0xFFEF9A9A),
          icon: Icons.error_outline,
        );
      case AppNoticeType.info:
        return const _NoticeScheme(
          bg: NovaColors.bgPrimary,
          fg: NovaColors.textPrimary,
          border: NovaColors.borderSecondary,
          icon: Icons.notifications_none_rounded,
        );
    }
  }
}

class _NoticeScheme {
  const _NoticeScheme({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });

  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;
}

