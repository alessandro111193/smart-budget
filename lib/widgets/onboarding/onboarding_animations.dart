import 'package:flutter/material.dart';

/// Blocchi di animazione riusati in tutte le schermate della mini demo
/// dell'onboarding. Solo widget nativi Flutter (AnimatedOpacity,
/// AnimatedSlide, TweenAnimationBuilder) — nessuna libreria di animazione
/// esterna, come richiesto (leggero, nessuna dipendenza in più).

/// Fa comparire [child] con un fade + leggero slide dal basso, dopo
/// [delay] dalla prima build. Usarlo per far apparire gli elementi di una
/// schermata demo in sequenza invece che tutti insieme.
class DelayedEntrance extends StatefulWidget {
  const DelayedEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 0.08,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<DelayedEntrance> createState() => _DelayedEntranceState();
}

class _DelayedEntranceState extends State<DelayedEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : Offset(0, widget.offsetY),
      child: AnimatedOpacity(
        duration: widget.duration,
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

/// Fa fluttuare [child] su e giù in loop continuo (leggero bob verticale +
/// pulsazione di scala), per dare vita a un mascotte/icona statica senza
/// serie di frame o librerie esterne — solo un `AnimationController` con
/// `Tween` sinusoidale nativo Flutter.
class FloatingBounce extends StatefulWidget {
  const FloatingBounce({
    super.key,
    required this.child,
    this.amplitude = 8,
    this.duration = const Duration(milliseconds: 1800),
  });

  final Widget child;
  final double amplitude;
  final Duration duration;

  @override
  State<FloatingBounce> createState() => _FloatingBounceState();
}

class _FloatingBounceState extends State<FloatingBounce>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final dy = widget.amplitude * (1 - t) - widget.amplitude / 2;
        final scale = 1 + 0.04 * t;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Conta da 0 (o da [begin]) a [end] in [duration], richiamando [builder]
/// ad ogni frame con il valore corrente — usarlo per "€0 → €2.400" o
/// "0% → 50%". Riparte automaticamente se [end] cambia.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.end,
    required this.builder,
    this.begin = 0,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
  });

  final double begin;
  final double end;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Future.delayed(delay),
      builder: (context, snapshot) {
        final started = snapshot.connectionState == ConnectionState.done;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: begin, end: started ? end : begin),
          duration: duration,
          curve: curve,
          builder: (context, value, _) => builder(context, value),
        );
      },
    );
  }
}
