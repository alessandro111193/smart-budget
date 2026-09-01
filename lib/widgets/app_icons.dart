import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/icon_palette.dart';

/// Sistema di icone centralizzato dell'app — vedi CLAUDE.md ("Design
/// System — Icone custom"). Usa il pacchetto `heroicons` (icone SVG con
/// stile "outline"/"solid" coerente su tutta la libreria — nessun asset
/// per icona da gestire a mano, un solo font/set con lo stesso tratto
/// pulito e arrotondato ovunque) invece delle `Icons.*` di Material.
///
/// Nota tecnica: la libreria di icone inizialmente scelta per questo
/// sistema (`phosphor_flutter`) risultava incompatibile con l'SDK
/// Flutter di questo progetto (estende `IconData`, diventata una classe
/// `final` non più estendibile nelle versioni recenti di Flutter — build
/// web verificata fallire con quell'errore). `heroicons` disegna le
/// icone via SVG (nessuna sottoclasse di `IconData`), quindi non ha
/// questo problema — verificato con una build web reale completata con
/// successo.
///
/// Non chiamare mai `HeroIcons.*`/`Icons.*` direttamente in una
/// schermata per una categoria o un'azione già mappata qui sotto: usare
/// [CategoryIcon] o [ActionIcon], così un domani basta cambiare la mappa
/// in questo file per aggiornare l'icona ovunque sia usata nell'app.

/// Le categorie di spesa/busta richieste dal Design System. [altro] è il
/// fallback per qualunque categoria non ancora mappata esplicitamente.
enum CategoryType {
  casa,
  auto,
  spesa,
  svago,
  salute,
  famiglia,
  scuola,
  figli,
  sport,
  abbigliamento,
  ristoranti,
  bollette,
  affitto,
  mutuo,
  assicurazioni,
  carburante,
  trasporti,
  viaggi,
  regali,
  hobby,
  tecnologia,
  abbonamenti,
  risparmio,
  investimenti,
  obiettivi,
  altro,
}

/// Le azioni principali richieste dal Design System (bottoni/scorciatoie
/// che compaiono in più schermate: Home, AppBar, dashboard famiglia...).
enum ActionType {
  nuovaEntrata,
  nuovaSpesa,
  scanner,
  fotoProdotto,
  aiAssistant,
  listaSpesa,
  obiettivo,
  challenge,
  famiglia,
  notifiche,
  profilo,
  impostazioni,
  ricerca,
  filtri,
  condivisione,
  invitoMembro,
  premium,
}

/// Le 5 voci della barra di navigazione inferiore.
enum NavType { home, buste, spese, statistiche, ai }

class _IconSpec {
  final HeroIcons icon;
  final Color color;
  const _IconSpec(this.icon, this.color);
}

/// Mappa categoria -> (icona, colore). Colori assegnati secondo la
/// palette di riferimento (Casa=verde, Auto=blu, Spesa=arancione,
/// Svago=viola, ecc.) e riutilizzati su categorie affini per restare una
/// base coerente invece di un colore diverso per ognuna delle 26 voci.
const Map<CategoryType, _IconSpec> _categorySpecs = {
  CategoryType.casa: _IconSpec(HeroIcons.home, IconPalette.green),
  CategoryType.auto: _IconSpec(HeroIcons.truck, IconPalette.blue),
  CategoryType.spesa: _IconSpec(HeroIcons.shoppingCart, IconPalette.orange),
  CategoryType.svago: _IconSpec(HeroIcons.ticket, IconPalette.purple),
  CategoryType.salute: _IconSpec(HeroIcons.heart, IconPalette.red),
  CategoryType.famiglia: _IconSpec(HeroIcons.users, IconPalette.emerald),
  CategoryType.scuola: _IconSpec(HeroIcons.academicCap, IconPalette.indigo),
  CategoryType.figli: _IconSpec(HeroIcons.faceSmile, IconPalette.pink),
  CategoryType.sport: _IconSpec(HeroIcons.fire, IconPalette.orange),
  CategoryType.abbigliamento: _IconSpec(HeroIcons.sparkles, IconPalette.pink),
  CategoryType.ristoranti: _IconSpec(HeroIcons.cake, IconPalette.orange),
  CategoryType.bollette: _IconSpec(HeroIcons.documentText, IconPalette.amber),
  CategoryType.affitto: _IconSpec(
    HeroIcons.buildingOffice2,
    IconPalette.brown,
  ),
  CategoryType.mutuo: _IconSpec(
    HeroIcons.buildingLibrary,
    IconPalette.indigo,
  ),
  CategoryType.assicurazioni: _IconSpec(
    HeroIcons.shieldCheck,
    IconPalette.blue,
  ),
  CategoryType.carburante: _IconSpec(HeroIcons.bolt, IconPalette.orange),
  CategoryType.trasporti: _IconSpec(
    HeroIcons.arrowsRightLeft,
    IconPalette.blue,
  ),
  CategoryType.viaggi: _IconSpec(HeroIcons.paperAirplane, IconPalette.cyan),
  CategoryType.regali: _IconSpec(HeroIcons.gift, IconPalette.pink),
  CategoryType.hobby: _IconSpec(HeroIcons.puzzlePiece, IconPalette.purple),
  CategoryType.tecnologia: _IconSpec(
    HeroIcons.computerDesktop,
    IconPalette.blue,
  ),
  CategoryType.abbonamenti: _IconSpec(HeroIcons.arrowPath, IconPalette.purple),
  CategoryType.risparmio: _IconSpec(HeroIcons.banknotes, IconPalette.green),
  CategoryType.investimenti: _IconSpec(
    HeroIcons.rocketLaunch,
    IconPalette.emerald,
  ),
  CategoryType.obiettivi: _IconSpec(HeroIcons.flag, IconPalette.teal),
  CategoryType.altro: _IconSpec(HeroIcons.squares2x2, IconPalette.gray),
};

/// Mappa azione -> (icona, colore).
const Map<ActionType, _IconSpec> _actionSpecs = {
  ActionType.nuovaEntrata: _IconSpec(HeroIcons.plusCircle, IconPalette.green),
  ActionType.nuovaSpesa: _IconSpec(HeroIcons.minusCircle, IconPalette.orange),
  ActionType.scanner: _IconSpec(HeroIcons.qrCode, IconPalette.purple),
  ActionType.fotoProdotto: _IconSpec(HeroIcons.camera, IconPalette.purple),
  ActionType.aiAssistant: _IconSpec(HeroIcons.sparkles, IconPalette.amber),
  ActionType.listaSpesa: _IconSpec(
    HeroIcons.clipboardDocumentList,
    IconPalette.blue,
  ),
  ActionType.obiettivo: _IconSpec(HeroIcons.flag, IconPalette.teal),
  ActionType.challenge: _IconSpec(HeroIcons.trophy, IconPalette.teal),
  ActionType.famiglia: _IconSpec(HeroIcons.users, IconPalette.emerald),
  ActionType.notifiche: _IconSpec(HeroIcons.bell, IconPalette.gray),
  ActionType.profilo: _IconSpec(HeroIcons.userCircle, IconPalette.primary),
  ActionType.impostazioni: _IconSpec(HeroIcons.cog6Tooth, IconPalette.gray),
  ActionType.ricerca: _IconSpec(HeroIcons.magnifyingGlass, IconPalette.gray),
  ActionType.filtri: _IconSpec(
    HeroIcons.adjustmentsHorizontal,
    IconPalette.gray,
  ),
  ActionType.condivisione: _IconSpec(HeroIcons.share, IconPalette.blue),
  ActionType.invitoMembro: _IconSpec(
    HeroIcons.userPlus,
    IconPalette.emerald,
  ),
  ActionType.premium: _IconSpec(HeroIcons.star, IconPalette.purple),
};

/// Mappa voce di navigazione -> icona (il colore della barra di
/// navigazione segue lo stato selezionato/non selezionato, non la
/// categoria — stesso pattern già in uso in `bottom_nav_shell.dart`).
const Map<NavType, HeroIcons> _navIcons = {
  NavType.home: HeroIcons.home,
  NavType.buste: HeroIcons.wallet,
  NavType.spese: HeroIcons.receiptPercent,
  NavType.statistiche: HeroIcons.chartBarSquare,
  NavType.ai: HeroIcons.sparkles,
};

/// Icona semplice, senza contenitore. Blocco base su cui sono costruiti
/// [CategoryIcon]/[ActionIcon]/[NavIcon] — usarla direttamente solo per
/// un'icona custom che non rientra in nessuna categoria/azione mappata.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.solid = false,
  });

  final HeroIcons icon;
  final double size;
  final Color? color;

  /// Tratto pieno invece che outline (es. stato selezionato).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return HeroIcon(
      icon,
      style: solid ? HeroIconStyle.solid : HeroIconStyle.outline,
      size: size,
      color: color ?? IconPalette.testo,
    );
  }
}

/// Icona di categoria dentro un contenitore colorato coerente col colore
/// di quella categoria — uso: `CategoryIcon(type: CategoryType.casa)`.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.type,
    this.size = 40,
    this.iconSize,
    this.square = false,
  });

  final CategoryType type;

  /// Diametro (o lato, se [square]) del contenitore.
  final double size;

  /// Dimensione dell'icona; se null, 50% di [size].
  final double? iconSize;

  /// Contenitore quadrato arrotondato invece che circolare.
  final bool square;

  @override
  Widget build(BuildContext context) {
    final spec = _categorySpecs[type] ?? _categorySpecs[CategoryType.altro]!;
    return _IconContainer(
      icon: spec.icon,
      color: spec.color,
      size: size,
      iconSize: iconSize,
      square: square,
    );
  }
}

/// Icona di azione dentro un contenitore colorato — uso:
/// `ActionIcon(type: ActionType.scanner)`.
class ActionIcon extends StatelessWidget {
  const ActionIcon({
    super.key,
    required this.type,
    this.size = 40,
    this.iconSize,
    this.square = false,
  });

  final ActionType type;
  final double size;
  final double? iconSize;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final spec = _actionSpecs[type]!;
    return _IconContainer(
      icon: spec.icon,
      color: spec.color,
      size: size,
      iconSize: iconSize,
      square: square,
    );
  }
}

class _IconContainer extends StatelessWidget {
  const _IconContainer({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.square,
  });

  final HeroIcons icon;
  final Color color;
  final double size;
  final double? iconSize;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(size * 0.28) : null,
      ),
      child: HeroIcon(icon, size: iconSize ?? size * 0.5, color: color),
    );
  }
}

/// Icona per la barra di navigazione inferiore: nessun contenitore
/// colorato (segue lo stile della bottom bar), solo tratto "outline" da
/// non selezionata e "solid" + colore primario da selezionata.
class NavIcon extends StatelessWidget {
  const NavIcon({
    super.key,
    required this.type,
    required this.selected,
    this.size = 24,
    this.badgeCount,
  });

  final NavType type;
  final bool selected;
  final double size;

  /// Se valorizzato (>0), mostra un badge numerico in alto a destra.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final icon = _navIcons[type]!;
    final color = selected ? IconPalette.primary : IconPalette.accent;
    final iconWidget = HeroIcon(
      icon,
      style: selected ? HeroIconStyle.solid : HeroIconStyle.outline,
      size: size,
      color: color,
    );
    if (badgeCount == null || badgeCount! <= 0) return iconWidget;
    return IconBadge(count: badgeCount!, child: iconWidget);
  }
}

/// Badge numerico sovrapposto a un'icona qualsiasi — uso:
/// `IconBadge(count: 3, child: AppIcon(...))`.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
