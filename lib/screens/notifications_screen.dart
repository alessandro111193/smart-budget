import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/icon_palette.dart';
import '../widgets/app_icons.dart';

/// Elenco cronologico delle notifiche inviate (avvisi budget Free,
/// promemoria "nessuna spesa", consiglio del giorno Premium) — consultabile
/// in qualunque momento, non solo la notifica di sistema che sparisce.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  HeroIcons _iconFor(String type) {
    switch (type) {
      case 'budget_alert':
        return HeroIcons.exclamationTriangle;
      case 'ai_daily_tip':
        return HeroIcons.sparkles;
      default:
        return HeroIcons.bell;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'budget_alert':
        return AppColors.warning;
      case 'ai_daily_tip':
        return IconPalette.amber;
      default:
        return AppColors.primary;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ora';
    if (diff.inHours < 1) return '${diff.inMinutes} min fa';
    if (diff.inDays < 1) return '${diff.inHours} h fa';
    if (diff.inDays < 7) return '${diff.inDays} g fa';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifiche',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.streamNotifications(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      HeroIcons.bell,
                      size: 40,
                      color: AppColors.neutral.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Nessuna notifica per ora',
                      style: TextStyle(color: AppColors.neutral),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, i) {
              final n = notifications[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: n.read
                      ? null
                      : () => NotificationService.markRead(n.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.read
                          ? const Color(0xFFF8FAFC)
                          : AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              _colorFor(n.type).withValues(alpha: 0.12),
                          child: AppIcon(
                            _iconFor(n.type),
                            size: 18,
                            solid: true,
                            color: _colorFor(n.type),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (!n.read)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.neutral,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _timeAgo(n.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.neutral.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
