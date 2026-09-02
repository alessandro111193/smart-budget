import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestisce il permesso di notifica (richiesto una sola volta, mai al
/// primissimo avvio — solo dopo il wizard di configurazione o, per un
/// account già esistente, alla prima apertura utile della Home) e il
/// salvataggio del token FCM su Firestore, così le Cloud Function possono
/// inviare le notifiche push (avvisi Free giornalieri, contenuti AI
/// proattivi Premium).
class NotificationService {
  static const _promptedKey = 'notification_prompt_done';

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Chiede il permesso una sola volta per dispositivo (il flag resta true
  /// sia che l'utente conceda sia che neghi — non ripresentiamo il prompt
  /// automaticamente, l'utente può comunque riattivarlo dalle impostazioni
  /// del sistema/browser). Se già chiesto in passato, si limita a
  /// ri-salvare il token corrente (può cambiare nel tempo).
  static Future<void> requestPermissionOnceIfNeeded() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_promptedKey) ?? false;

    if (!alreadyPrompted) {
      await prefs.setBool(_promptedKey, true);
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    }
    await _saveCurrentToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _saveCurrentToken());
  }

  static Future<void> _saveCurrentToken() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Permesso negato o token non disponibile (es. web senza VAPID key
      // configurata) — nessuna notifica per questo dispositivo, non blocca
      // il resto dell'app.
    }
  }

  /// Storico delle notifiche inviate (scritte dalle Cloud Function via
  /// Admin SDK), consultabile in qualunque momento dalla schermata
  /// "Notifiche" — non solo la notifica di sistema, che sparisce.
  static Stream<List<AppNotification>> streamNotifications() {
    final userId = _userId;
    if (userId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(AppNotification.fromDoc).toList());
  }

  static Future<void> markRead(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      read: data['read'] == true,
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
