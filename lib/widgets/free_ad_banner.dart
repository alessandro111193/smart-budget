import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// Banner AdMob mostrato solo agli utenti Free (vedi [AdService] per la
/// regola completa). Non occupa spazio finché l'annuncio non è caricato, e
/// scompare di nuovo se il caricamento fallisce o l'utente diventa
/// Premium/Trial mentre la schermata è aperta.
class FreeAdBanner extends StatefulWidget {
  const FreeAdBanner({super.key, required this.show});

  final bool show;

  @override
  State<FreeAdBanner> createState() => _FreeAdBannerState();
}

class _FreeAdBannerState extends State<FreeAdBanner> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.show) _loadBanner();
  }

  @override
  void didUpdateWidget(FreeAdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && _banner == null) {
      _loadBanner();
    } else if (!widget.show && _banner != null) {
      _disposeBanner();
    }
  }

  void _loadBanner() {
    if (!AdService.isSupportedPlatform) return;
    final banner = AdService.createBanner(onFailed: _disposeBanner);
    banner.load().then((_) {
      if (!mounted) {
        banner.dispose();
        return;
      }
      setState(() {
        _banner = banner;
        _loaded = true;
      });
    });
  }

  void _disposeBanner() {
    _banner?.dispose();
    if (mounted) {
      setState(() {
        _banner = null;
        _loaded = false;
      });
    } else {
      _banner = null;
      _loaded = false;
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show || !_loaded || _banner == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        width: _banner!.size.width.toDouble(),
        height: _banner!.size.height.toDouble(),
        child: AdWidget(ad: _banner!),
      ),
    );
  }
}
