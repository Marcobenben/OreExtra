import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TurnazioneSettingsPage extends StatefulWidget {
  const TurnazioneSettingsPage({super.key});

  @override
  State<TurnazioneSettingsPage> createState() => _TurnazioneSettingsPageState();
}

class _TurnazioneSettingsPageState extends State<TurnazioneSettingsPage> {
  String _tipoTurnazione = '6+1+1';
  TimeOfDay _orarioStandard = const TimeOfDay(hour: 7, minute: 15);
  DateTime? _primoRiposo;
  int _numeroTurno = 1;

  Map<DateTime, bool> mappaGiorni = {};

  Future<void> _selezionaOra(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _orarioStandard,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _orarioStandard = picked;
      });
    }
  }

  Future<void> _selezionaData(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
      locale: const Locale('it', 'IT'),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _primoRiposo = picked;
      });
    }
  }


  Future<void> _salvaImpostazioni() async {
    debugPrint('Tipo turnazione: $_tipoTurnazione');
    debugPrint('Orario standard: ${_orarioStandard.format(context)}');
    debugPrint('Numero turno: $_numeroTurno');
    if (_tipoTurnazione == '6+1+1') {
      debugPrint('Primo giorno di riposo: $_primoRiposo');
    }

    if (_tipoTurnazione == '6+1+1' && _primoRiposo != null) {
      mappaGiorni = _generaMappaTurnazione6x1x1(_primoRiposo!);
    } else if (_tipoTurnazione == '5+1+1') {
      mappaGiorni = _generaMappaTurnazione5x1x1();
    }

    await _salvaMappaGiorni(mappaGiorni);

    debugPrint('Giorni generati e salvati.');

    if (!mounted) return;
    Navigator.pop(context);
  }


  Map<DateTime, bool> _generaMappaTurnazione6x1x1(DateTime primoRiposo) {
    final Map<DateTime, bool> mappa = {};
    DateTime giorno = primoRiposo;
    final DateTime fine = DateTime.utc(2090, 12, 31);

    while (giorno.isBefore(fine)) {
      mappa[giorno] = false;
      giorno = giorno.add(const Duration(days: 1));
      mappa[giorno] = false;
      giorno = giorno.add(const Duration(days: 1));

      for (int i = 0; i < 6; i++) {
        mappa[giorno] = true;
        giorno = giorno.add(const Duration(days: 1));
      }
    }
    return mappa;
  }

  Map<DateTime, bool> _generaMappaTurnazione5x1x1() {
    final Map<DateTime, bool> mappa = {};
    final DateTime inizio = DateTime.now();
    final DateTime fine = DateTime.utc(2090, 12, 31);
    DateTime giorno = inizio;

    while (giorno.isBefore(fine)) {
      final isWeekend = giorno.weekday == DateTime.saturday || giorno.weekday == DateTime.sunday;
      mappa[giorno] = !isWeekend;
      giorno = giorno.add(const Duration(days: 1));
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
  }

  Future<Map<DateTime, bool>> caricaMappaGiorni() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('mappaGiorniTurno');
    if (jsonString == null) return {};

    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    final Map<DateTime, bool> result = {};
    jsonData.forEach((key, value) {
      result[DateTime.parse(key)] = value as bool;
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Impostazioni Turnazione")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tipo di turnazione", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _tipoTurnazione,
              items: const [
                DropdownMenuItem(value: '6+1+1', child: Text('6 + 1 + 1')),
                DropdownMenuItem(value: '5+1+1', child: Text('5 + 1 + 1')),
              ],
              onChanged: (value) {
                setState(() {
                  _tipoTurnazione = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            if (_tipoTurnazione == '6+1+1') ...[
              const Text("Turno di riferimento", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButton<int>(
                value: _numeroTurno,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1° turno')),
                  DropdownMenuItem(value: 2, child: Text('2° turno')),
                  DropdownMenuItem(value: 3, child: Text('3° turno')),
                  DropdownMenuItem(value: 4, child: Text('4° turno')),
                ],
                onChanged: (value) {
                  setState(() {
                    _numeroTurno = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Orario standard giornaliero:", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: () => _selezionaOra(context),
                  child: Text(_orarioStandard.format(context)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_tipoTurnazione == '6+1+1')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Primo giorno di riposo:", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () => _selezionaData(context),
                    child: Text(
                      _primoRiposo == null
                          ? 'Seleziona'
                          : '${_primoRiposo!.day}/${_primoRiposo!.month}/${_primoRiposo!.year}',
                    ),
                  ),
                ],
              ),

            const Spacer(),
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

