import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../models/envelope.dart';
import '../models/expense.dart';
import '../utils/amount_input.dart';
import '../widgets/trial_quota_badge.dart';

enum _PhotoMode { receiptOnly, productsOnly, both }

const _categorie = [
  'Spesa',
  'Casa',
  'Trasporti',
  'Salute',
  'Svago',
  'Altro',
];

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final _aiService = AiService();
  final _firestoreService = FirestoreService();

  _PhotoMode _mode = _PhotoMode.receiptOnly;
  Uint8List? _receiptBytes;
  Uint8List? _productsBytes;

  bool _loading = false;
  List<Map<String, dynamic>> _products = [];
  String? _error;

  /// Media storica di spesa per categoria (solo Dart/Firestore, zero
  /// costo AI): calcolata dopo lo scan per confrontarla con il totale di
  /// questo scontrino, categoria per categoria. Non tocca in alcun modo
  /// la conferma manuale già esistente.
  Map<String, double> _historicalAverageByCategory = {};

  bool get _needsReceipt =>
      _mode == _PhotoMode.receiptOnly || _mode == _PhotoMode.both;
  bool get _needsProducts =>
      _mode == _PhotoMode.productsOnly || _mode == _PhotoMode.both;

  bool get _canScan =>
      (!_needsReceipt || _receiptBytes != null) &&
      (!_needsProducts || _productsBytes != null);

  // Usa XFile.readAsBytes() + compressWithList (non compressWithFile) perché
  // su web il path di XFile è un blob URL: dart:io.File non lo apre e
  // compressWithFile non è implementato sul target web.
  Future<Uint8List?> _pickCompressed(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return FlutterImageCompress.compressWithList(
      bytes,
      quality: 70,
      minWidth: 1024,
    );
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final bytes = await _pickCompressed(source);
      if (bytes == null) return;
      setState(() => _receiptBytes = bytes);
    } catch (e) {
      setState(() => _error = 'Errore nella selezione della foto: $e');
    }
  }

  Future<void> _pickProducts(ImageSource source) async {
    try {
      final bytes = await _pickCompressed(source);
      if (bytes == null) return;
      setState(() => _productsBytes = bytes);
    } catch (e) {
      setState(() => _error = 'Errore nella selezione della foto: $e');
    }
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final envelopes = await _firestoreService.streamEnvelopes().first;
      final result = await _aiService.scanReceipt(
        receiptImageBytes: _needsReceipt ? _receiptBytes : null,
        productsImageBytes: _needsProducts ? _productsBytes : null,
        envelopeNames: envelopes.map((e) => e.name).toList(),
      );
      final rawProducts = List<Map<String, dynamic>>.from(
        result['prodotti'] ?? [],
      );
      final products = rawProducts.map((p) {
        final categoria = p['categoria'];
        final bustaNome = (p['busta'] as String?)?.trim().toLowerCase();
        String? envelopeId;
        if (bustaNome != null && bustaNome.isNotEmpty) {
          for (final e in envelopes) {
            if (e.name.trim().toLowerCase() == bustaNome) {
              envelopeId = e.id;
              break;
            }
          }
        }
        return {
          'nome': p['nome'] ?? '',
          'prezzo': (p['prezzo'] as num?)?.toDouble(),
          'quantita': (p['quantita'] as num?)?.toInt() ?? 1,
          'categoria': _categorie.contains(categoria) ? categoria : 'Altro',
          'abbinato': p['abbinato'] == true,
          'envelopeId': envelopeId,
        };
      }).toList();

      // Se l'utente non ha ancora nessuna busta, non possiamo chiedergli
      // dove salvare: ne creiamo una per categoria trovata, con budget
      // pari a quanto speso in quella categoria in questo scontrino.
      if (envelopes.isEmpty && products.isNotEmpty) {
        await _createEnvelopesForProducts(products);
      }

      final historicalAverages = await _computeHistoricalAverages(products);

      setState(() {
        _products = products;
        _historicalAverageByCategory = historicalAverages;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  static const _categoryIcons = {
    'Spesa': '🛒',
    'Casa': '🏠',
    'Trasporti': '🚗',
    'Salute': '💊',
    'Svago': '🎉',
    'Altro': '💰',
  };

  Future<void> _createEnvelopesForProducts(
    List<Map<String, dynamic>> products,
  ) async {
    final totals = <String, double>{};
    for (final p in products) {
      final categoria = p['categoria'] as String;
      final prezzo = (p['prezzo'] as double?) ?? 0;
      final quantita = (p['quantita'] as int?) ?? 1;
      totals[categoria] = (totals[categoria] ?? 0) + prezzo * quantita;
    }
    final newIds = <String, String>{};
    for (final entry in totals.entries) {
      newIds[entry.key] = await _firestoreService.addEnvelope(
        Envelope(
          id: '',
          name: entry.key,
          category: entry.key,
          budget: entry.value,
          balance: entry.value,
          icon: _categoryIcons[entry.key] ?? '💰',
        ),
      );
    }
    for (final p in products) {
      p['envelopeId'] = newIds[p['categoria']];
    }
  }

  /// Punto 11 del piano AI Premium: confronta il totale di questo
  /// scontrino, categoria per categoria, con la media storica delle spese
  /// già registrate in quella categoria. Solo Dart/Firestore, zero
  /// chiamate AI — non cambia in nulla il flusso di conferma manuale.
  Future<Map<String, double>> _computeHistoricalAverages(
    List<Map<String, dynamic>> products,
  ) async {
    final scannedCategories = products
        .map((p) => p['categoria'] as String)
        .toSet();
    if (scannedCategories.isEmpty) return {};

    final pastExpenses = await _firestoreService.streamExpenses().first;
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final e in pastExpenses) {
      if (!scannedCategories.contains(e.category)) continue;
      sums[e.category] = (sums[e.category] ?? 0) + e.amount;
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }

    return {
      for (final category in sums.keys) category: sums[category]! / counts[category]!,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scanner scontrino',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrialQuotaBadge(
              used: (u) => u.scontriniUsati,
              max: AppUser.trialMaxScontrini,
              label: 'Scontrini',
            ),
            _modeSelector(),
            const SizedBox(height: 16),
            if (_needsReceipt)
              _photoSlot(
                label: 'Foto scontrino',
                bytes: _receiptBytes,
                onPick: _pickReceipt,
              ),
            if (_needsReceipt && _needsProducts) const SizedBox(height: 12),
            if (_needsProducts)
              _photoSlot(
                label: 'Foto prodotti',
                bytes: _productsBytes,
                onPick: _pickProducts,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _canScan && !_loading ? _scan : null,
                child: const Text(
                  'Scansiona',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            if (_products.isNotEmpty) ...[
              _historicalComparisonCard(),
              const Text(
                'Controlla e correggi prima di salvare:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<Envelope>>(
                  stream: _firestoreService.streamEnvelopes(),
                  builder: (context, envSnapshot) {
                    final envelopes = envSnapshot.data ?? [];
                    return ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, i) => _productCard(i, envelopes),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _products.isEmpty ? null : _saveAll,
                  child: Text(
                    'Salva ${_products.length} spese',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return SegmentedButton<_PhotoMode>(
      segments: const [
        ButtonSegment(
          value: _PhotoMode.receiptOnly,
          label: Text('Scontrino'),
          icon: Icon(Icons.receipt_long),
        ),
        ButtonSegment(
          value: _PhotoMode.productsOnly,
          label: Text('Prodotti'),
          icon: Icon(Icons.shopping_bag_outlined),
        ),
        ButtonSegment(
          value: _PhotoMode.both,
          label: Text('Entrambe'),
          icon: Icon(Icons.compare_arrows),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) {
        setState(() {
          _mode = selection.first;
          _products = [];
          _historicalAverageByCategory = {};
          _error = null;
        });
      },
      style: SegmentedButton.styleFrom(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: AppColors.neutral,
        selectedBackgroundColor: AppColors.primary.withOpacity(0.12),
        selectedForegroundColor: AppColors.primary,
        side: BorderSide(color: Colors.grey.shade200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Card "confronto con lo storico" (punto 11): mostra il totale di
  /// questo scontrino per ogni categoria già presente nello storico spese,
  /// affiancato alla media storica di quella categoria. Solo informativa —
  /// non blocca né modifica in alcun modo il salvataggio.
  Widget _historicalComparisonCard() {
    if (_historicalAverageByCategory.isEmpty) return const SizedBox.shrink();

    final scannedTotals = <String, double>{};
    for (final p in _products) {
      final categoria = p['categoria'] as String;
      final prezzo = (p['prezzo'] as double?) ?? 0;
      final quantita = (p['quantita'] as int?) ?? 1;
      scannedTotals[categoria] =
          (scannedTotals[categoria] ?? 0) + prezzo * quantita;
    }

    final categories = _historicalAverageByCategory.keys
        .where((c) => (scannedTotals[c] ?? 0) > 0)
        .toList();
    if (categories.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confronto con lo storico',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ...categories.map((category) {
            final total = scannedTotals[category]!;
            final average = _historicalAverageByCategory[category]!;
            final isHigher = total > average * 1.2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '$category: questo scontrino €${total.toStringAsFixed(2)} '
                '(media storica €${average.toStringAsFixed(2)})',
                style: TextStyle(
                  fontSize: 11,
                  color: isHigher ? AppColors.warning : AppColors.neutral,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _photoSlot({
    required String label,
    required Uint8List? bytes,
    required void Function(ImageSource) onPick,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.memory(
                bytes,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          else
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.accent.withOpacity(0.12),
              child: const Icon(Icons.image_outlined, color: AppColors.accent),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bytes != null ? '$label pronta' : label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt, color: AppColors.primary),
            onPressed: () => onPick(ImageSource.camera),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library, color: AppColors.primary),
            onPressed: () => onPick(ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  /// Crea una nuova busta al volo senza uscire dallo Scanner, riusando lo
  /// stesso servizio del form spesa normale (`new_expense_screen.dart`).
  Future<String?> _createEnvelopeInline() async {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Nuova busta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome busta'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetController,
              keyboardType: amountKeyboardType,
              decoration: const InputDecoration(
                labelText: 'Budget mensile (€) — opzionale',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.neutral),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: nameController.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text(
              'Crea',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (created != true || nameController.text.trim().isEmpty) return null;
    final budget = parseAmount(budgetController.text) ?? 0;
    return _firestoreService.addEnvelope(
      Envelope(
        id: '',
        name: nameController.text.trim(),
        category: nameController.text.trim(),
        budget: budget,
        balance: budget,
        icon: '💰',
      ),
    );
  }

  Widget _productCard(int index, List<Envelope> envelopes) {
    final product = _products[index];
    final showAbbinato = _mode == _PhotoMode.both;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: product['nome'],
                    decoration: const InputDecoration(
                      labelText: 'Prodotto',
                      isDense: true,
                    ),
                    onChanged: (v) => product['nome'] = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: product['quantita'].toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qtà',
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        product['quantita'] = int.tryParse(v) ?? 1,
                  ),
                ),
              ],
            ),
            if (showAbbinato)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (product['abbinato'] == true
                              ? AppColors.primary
                              : AppColors.warning)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product['abbinato'] == true
                          ? 'Abbinato allo scontrino'
                          : 'Prezzo da verificare',
                      style: TextStyle(
                        fontSize: 11,
                        color: product['abbinato'] == true
                            ? AppColors.primary
                            : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: product['prezzo']?.toString() ?? '',
                    keyboardType: amountKeyboardType,
                    decoration: const InputDecoration(
                      labelText: '€',
                      isDense: true,
                    ),
                    onChanged: (v) => product['prezzo'] = parseAmount(v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    isDense: true,
                    initialValue: product['categoria'],
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      isDense: true,
                    ),
                    items: _categorie
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) => product['categoria'] = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // Vedi commento analogo in new_expense_screen.dart: forza il
              // remount del FormField quando la selezione cambia via codice
              // (dopo "+ Nuova busta"), non solo con un tap diretto.
              key: ValueKey('${index}_${product['envelopeId']}'),
              isDense: true,
              initialValue:
                  product['envelopeId'] == kGeneralEnvelopeSentinel ||
                          envelopes.any((e) => e.id == product['envelopeId'])
                      ? product['envelopeId']
                      : null,
              decoration: InputDecoration(
                labelText: 'Busta',
                isDense: true,
                hintText: 'Seleziona busta',
                errorText: product['envelopeId'] == null
                    ? 'Obbligatoria'
                    : null,
              ),
              items: [
                ...envelopes.where((e) => !e.isGeneral).map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                const DropdownMenuItem(
                  value: kGeneralEnvelopeSentinel,
                  child: Text('📦 Spese generali'),
                ),
                const DropdownMenuItem(
                  value: kNewEnvelopeSentinel,
                  child: Text(
                    '+ Nuova busta',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              onChanged: (v) async {
                if (v == kNewEnvelopeSentinel) {
                  final newId = await _createEnvelopeInline();
                  if (newId != null && mounted) {
                    setState(() => product['envelopeId'] = newId);
                  }
                  return;
                }
                setState(() => product['envelopeId'] = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAll() async {
    if (_products.any((p) => p['envelopeId'] == null)) {
      setState(() {
        _error = 'Seleziona una busta per ogni prodotto prima di salvare.';
      });
      return;
    }
    String? generalEnvelopeId;
    for (final p in _products) {
      final quantita = (p['quantita'] as int?) ?? 1;
      final prezzo = (p['prezzo'] as double?) ?? 0;
      final nome = p['nome'] ?? '';
      var envelopeId = p['envelopeId'] as String;
      if (envelopeId == kGeneralEnvelopeSentinel) {
        generalEnvelopeId ??= await _firestoreService.ensureGeneralEnvelope();
        envelopeId = generalEnvelopeId;
      }
      await _firestoreService.addExpense(
        Expense(
          id: '',
          amount: prezzo * quantita,
          category: p['categoria'] ?? 'Altro',
          envelopeId: envelopeId,
          description: quantita > 1 ? '$nome (x$quantita)' : nome,
          date: DateTime.now(),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }
}
