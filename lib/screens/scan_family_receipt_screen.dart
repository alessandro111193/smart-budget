import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/family_service.dart';
import '../models/app_user.dart';
import '../models/envelope.dart';
import '../models/family.dart';
import '../models/family_expense.dart';
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

/// Scanner scontrino/prodotti per il flusso di spesa familiare (Fase F del
/// piano post-beta). Stessa Cloud Function `scanReceipt` già usata dallo
/// scanner personale (`scan_receipt_screen.dart`), qui abbinata alle buste
/// familiari invece che a quelle personali. Premium/Trial: il gate reale è
/// server-side dentro `scanReceipt` (verificato sull'utente personale che
/// chiama, non sulla famiglia — stesso pattern già in uso per l'analisi AI
/// famiglia), l'accesso a questa schermata è comunque già filtrato dal
/// bottone che la apre in `family_screen.dart`.
///
/// A differenza dello scanner personale: nessuna busta "Spese generali"
/// (mai introdotta per le buste familiari, scelta di scope del Block 2) e
/// il tipo di spesa familiare (condivisa/personale) si sceglie una sola
/// volta per l'intero scontrino, non prodotto per prodotto — un'unica spesa
/// al supermercato ha senso averla con lo stesso "chi paga" per ogni riga.
/// La modalità "ripartita" non è supportata qui: richiederebbe percentuali
/// per ogni singolo prodotto, sproporzionato per una spesa a scontrino;
/// resta disponibile con il form manuale (`new_family_expense_screen.dart`).
class ScanFamilyReceiptScreen extends StatefulWidget {
  final String familyId;
  const ScanFamilyReceiptScreen({super.key, required this.familyId});

  @override
  State<ScanFamilyReceiptScreen> createState() =>
      _ScanFamilyReceiptScreenState();
}

class _ScanFamilyReceiptScreenState extends State<ScanFamilyReceiptScreen> {
  final _aiService = AiService();
  final _familyService = FamilyService();

  _PhotoMode _mode = _PhotoMode.receiptOnly;
  Uint8List? _receiptBytes;
  Uint8List? _productsBytes;

  FamilyExpenseType _type = FamilyExpenseType.shared;
  String? _selectedMemberId;

  bool _loading = false;
  List<Map<String, dynamic>> _products = [];
  String? _error;

  bool get _needsReceipt =>
      _mode == _PhotoMode.receiptOnly || _mode == _PhotoMode.both;
  bool get _needsProducts =>
      _mode == _PhotoMode.productsOnly || _mode == _PhotoMode.both;

  bool get _canScan =>
      (!_needsReceipt || _receiptBytes != null) &&
      (!_needsProducts || _productsBytes != null);

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
      final envelopes =
          await _familyService.streamFamilyEnvelopes(widget.familyId).first;
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

      setState(() => _products = products);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scanner scontrino famiglia',
          style: TextStyle(color: AppColors.ink, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: StreamBuilder<List<FamilyMember>>(
        stream: _familyService.streamMembers(widget.familyId),
        builder: (context, memberSnapshot) {
          final members = memberSnapshot.data ?? [];
          return Padding(
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
                if (_needsReceipt && _needsProducts)
                  const SizedBox(height: 12),
                if (_needsProducts)
                  _photoSlot(
                    label: 'Foto prodotti',
                    bytes: _productsBytes,
                    onPick: _pickProducts,
                  ),
                const SizedBox(height: 16),
                _typeSelector(members),
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
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                if (_products.isNotEmpty) ...[
                  const Text(
                    'Controlla e correggi prima di salvare:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<List<Envelope>>(
                      stream:
                          _familyService.streamFamilyEnvelopes(widget.familyId),
                      builder: (context, envSnapshot) {
                        final envelopes = envSnapshot.data ?? [];
                        return ListView.builder(
                          itemCount: _products.length,
                          itemBuilder: (context, i) =>
                              _productCard(i, envelopes),
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
                      onPressed: _canSave() ? () => _saveAll(members) : null,
                      child: Text(
                        'Salva ${_products.length} spese',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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

  Widget _typeSelector(List<FamilyMember> members) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi paga questa spesa?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          RadioListTile<FamilyExpenseType>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Condivisa (a carico di tutta la famiglia)'),
            activeColor: AppColors.primary,
            value: FamilyExpenseType.shared,
            groupValue: _type,
            onChanged: (v) => setState(() => _type = v!),
          ),
          RadioListTile<FamilyExpenseType>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Personale (a carico di un solo membro)'),
            activeColor: AppColors.primary,
            value: FamilyExpenseType.personal,
            groupValue: _type,
            onChanged: (v) => setState(() => _type = v!),
          ),
          if (_type == FamilyExpenseType.personal)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButtonFormField<String>(
                isDense: true,
                initialValue: _selectedMemberId,
                decoration: const InputDecoration(
                  labelText: 'Di chi è la spesa?',
                  isDense: true,
                ),
                items: members
                    .map(
                      (m) =>
                          DropdownMenuItem(value: m.userId, child: Text(m.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedMemberId = v),
              ),
            ),
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

  /// Crea una nuova busta familiare al volo senza uscire dallo Scanner,
  /// stesso pattern già in uso in `scan_receipt_screen.dart` per le buste
  /// personali.
  Future<String?> _createEnvelopeInline() async {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Nuova busta familiare'),
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
              keyboardType: TextInputType.number,
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
    final budget = double.tryParse(budgetController.text) ?? 0;
    return _familyService.addFamilyEnvelope(
      widget.familyId,
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
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '€',
                      isDense: true,
                    ),
                    onChanged: (v) => product['prezzo'] = double.tryParse(v),
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
              key: ValueKey('${index}_${product['envelopeId']}'),
              isDense: true,
              initialValue: envelopes.any((e) => e.id == product['envelopeId'])
                  ? product['envelopeId']
                  : null,
              decoration: InputDecoration(
                labelText: 'Busta familiare',
                isDense: true,
                hintText: 'Seleziona busta',
                errorText: product['envelopeId'] == null
                    ? 'Obbligatoria'
                    : null,
              ),
              items: [
                ...envelopes.map(
                  (e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      '${e.icon} ${e.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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

  bool _canSave() {
    if (_products.isEmpty) return false;
    if (_products.any((p) => p['envelopeId'] == null)) return false;
    if (_type == FamilyExpenseType.personal) return _selectedMemberId != null;
    return true;
  }

  Future<void> _saveAll(List<FamilyMember> members) async {
    if (_products.any((p) => p['envelopeId'] == null)) {
      setState(() {
        _error = 'Seleziona una busta per ogni prodotto prima di salvare.';
      });
      return;
    }
    if (_type == FamilyExpenseType.personal && _selectedMemberId == null) {
      setState(() => _error = 'Seleziona di chi è la spesa prima di salvare.');
      return;
    }
    for (final p in _products) {
      final quantita = (p['quantita'] as int?) ?? 1;
      final prezzo = (p['prezzo'] as double?) ?? 0;
      final nome = p['nome'] ?? '';
      final envelopeId = p['envelopeId'] as String;
      await _familyService.addFamilyExpense(
        widget.familyId,
        FamilyExpense(
          id: '',
          amount: prezzo * quantita,
          description: quantita > 1 ? '$nome (x$quantita)' : nome,
          envelopeId: envelopeId,
          date: DateTime.now(),
          type: _type,
          memberId: _type == FamilyExpenseType.personal
              ? _selectedMemberId
              : null,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }
}
