import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class TurnazioneSettingsPage extends StatefulWidget {
  const TurnazioneSettingsPage({super.key});

  @override
  State<TurnazioneSettingsPage> createState() => _TurnazioneSettingsPageState();
}

class _TurnazioneSettingsPageState extends State<TurnazioneSettingsPage> {
  final TextEditingController _lavoroController = TextEditingController();
  final TextEditingController _riposiController = TextEditingController();
  final TextEditingController _orarioController = TextEditingController();
  int? _numeroTurno;
  DateTime? _dataPartenza;
  Map<DateTime, bool> mappaGiorni = {};
  bool _usaTurnazione = false;
  final TextEditingController _dataController = TextEditingController();

  Future<void> _selezionaDataPartenza(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
      locale: const Locale('it', 'IT'),
      helpText: 'Seleziona dal calendario qui sotto',
    );
    if (picked != null && mounted) {
      setState(() {
        _dataPartenza = picked;
        _dataController.text =
        "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _salvaImpostazioni() async {
    final giorniLavoro = int.tryParse(_lavoroController.text) ?? 0;
    final giorniRiposo = int.tryParse(_riposiController.text) ?? 0;
    final pattern = [
      ...List.filled(giorniLavoro, 'L'),
      ...List.filled(giorniRiposo, 'R')
    ];
    if (_dataPartenza != null) {
      mappaGiorni = _generaMappaTurnazioneCompleta(pattern, _dataPartenza!);
      print("Totale giorni generati: ${mappaGiorni.length}");
      await _salvaMappaGiorni(mappaGiorni);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Map<DateTime, bool> _generaMappaTurnazioneCompleta(List<String> pattern, DateTime partenza) {
    final Map<DateTime, bool> mappa = {};
    final DateTime inizio = DateTime(2020, 1, 1);
    final DateTime fine = DateTime(2099, 12, 31);
    final int offset = (partenza.difference(inizio).inDays + 1) % pattern.length;

    DateTime giorno = inizio;
    int index = 0;

    while (!giorno.isAfter(fine)) {
      final patternIndex = (index - offset + pattern.length) % pattern.length;
      mappa[giorno] = pattern[patternIndex] == 'L';
      giorno = giorno.add(const Duration(days: 1));
      index++;
    }

    return mappa;
  }

  Future<void> _salvaMappaGiorni(Map<DateTime, bool> mappa) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, bool> stringMap = {
      for (var entry in mappa.entries)
        entry.key.toIso8601String().split("T")[0]: entry.value
    };
    await prefs.setString('mappaGiorniTurno', jsonEncode(stringMap));
    debugPrint('💾 Salvati ${stringMap.length} giorni nella mappa turnazioni');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text("Impostazioni Turnazione")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Compila la tua turnazione", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: _lavoroController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Giorni di lavoro"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _riposiController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Giorni di riposo"),
            ),
            const SizedBox(height: 16),
            const Text("Orario standard giornaliero\n(es: 07:15)", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            TextField(
              controller: _orarioController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  String digits = newValue.text.replaceAll(':', '');
                  if (digits.length > 4) digits = digits.substring(0, 4);
                  String formatted = digits;
                  if (digits.length >= 3) {
                    formatted = digits.substring(0, 2) + ':' + digits.substring(2);
                  }
                  return TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                })
              ],
              decoration: const InputDecoration(hintText: ''),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text("Segui una turnazione ciclica"),
              value: _usaTurnazione,
              onChanged: (val) {
                setState(() => _usaTurnazione = val ?? false);
              },
            ),
            if (_usaTurnazione) ...[
              const SizedBox(height: 8),
              const Text("Turno di riferimento", style: TextStyle(fontSize: 16)),
              DropdownButton<int>(
                value: _numeroTurno,
                hint: const Text("Seleziona turno"),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1° turno')),
                  DropdownMenuItem(value: 2, child: Text('2° turno')),
                  DropdownMenuItem(value: 3, child: Text('3° turno')),
                  DropdownMenuItem(value: 4, child: Text('4° turno')),
                ],
                onChanged: (value) {
                  setState(() {
                    _numeroTurno = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            const Text("Data di inizio turno\n(primo giorno di lavoro)", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            TextField(
              controller: _dataController,
              readOnly: true,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(hintText: ''),
              onTap: () => _selezionaDataPartenza(context),
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: _salvaImpostazioni,
                icon: const Icon(Icons.save),
                label: const Text("Salva impostazioni"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
