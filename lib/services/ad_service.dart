import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// ID banner AdMob UFFICIALI DI TEST pubblicati da Google
/// (https://developers.google.com/admob/flutter/test-ads): sicuri da usare
/// in sviluppo, non richiedono un account AdMob e non generano impressioni
/// fatturabili né rischio di ban per click non validi.
///
/// TODO(admob-console): prima della pubblicazione su Play Store, sostituire
/// questi ID con quelli reali creati nel tuo account AdMob (un'app AdMob +
/// uno o più ad unit "Banner" collegati all'app Android), e aggiornare
/// anche l'APPLICATION_ID in `android/app/src/main/AndroidManifest.xml`
/// (oggi contiene anch'esso l'App ID di test di Google). Finché questi
/// restano gli ID di test, l'app mostra sempre banner di test — mai
/// pubblicità vera, quindi zero rischio di violare le policy AdMob durante
/// lo sviluppo.
const String _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
const String _testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';

/// Gestisce i banner pubblicitari AdMob per il piano Free.
///
/// Regola di prodotto (CLAUDE.md): solo gli utenti Free (né Premium né in
/// Trial attivo) vedono pubblicità. La decisione se mostrare un banner è
/// puramente di presentazione (a differenza dei limiti Premium/Trial per le
/// chiamate AI) e quindi è corretto valutarla lato client, in base allo
/// stato utente già letto da Firestore tramite `AppUser.hasAiAccess`.
class AdService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  static String get _bannerAdUnitId {
    if (Platform.isIOS) return _testBannerAdUnitIdIOS;
    return _testBannerAdUnitIdAndroid;
  }

  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static BannerAd createBanner({required void Function() onFailed}) {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed();
        },
      ),
    );
  }
}
