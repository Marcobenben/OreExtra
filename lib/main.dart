import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'turnazione_settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT', null);
  runApp(const OreExtraApp());
}

enum TextScaleOption { normale, medio, grande }

class OreExtraApp extends StatefulWidget {
  const OreExtraApp({super.key});

  @override
  State<OreExtraApp> createState() => _OreExtraAppState();
}

class _OreExtraAppState extends State<OreExtraApp> {
  TextScaleOption _textScaleOption = TextScaleOption.normale;

  @override
  void initState() {
    super.initState();
    _caricaPreferenze();
  }

  Future<void> _caricaPreferenze() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('textScaleOption') ?? 0;
    setState(() {
      _textScaleOption = TextScaleOption.values[index];
    });
  }

  Future<void> _salvaPreferenza(TextScaleOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('textScaleOption', option.index);
  }

  double _mapOptionToScale(TextScaleOption option) {
    switch (option) {
      case TextScaleOption.normale:
        return 1.30;
      case TextScaleOption.medio:
        return 1.50;
      case TextScaleOption.grande:
        return 1.80;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _mapOptionToScale(_textScaleOption);

    return MaterialApp(
      title: 'OreExtra',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.light,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'),
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
      home: HomePage(
        onScalaTestoCambiata: (TextScaleOption nuova) {
          setState(() {
            _textScaleOption = nuova;
          });
          _salvaPreferenza(nuova);
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final void Function(TextScaleOption) onScalaTestoCambiata;

  const HomePage({super.key, required this.onScalaTestoCambiata});

  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  DateTime _selectedDate = DateTime.now();
  final Map<DateTime, GiornoLavorativo> _giorni = {};
  Map<DateTime, bool> _mappaTurnazione = {};
  GiornoLavorativo get _oggi {
    return _giorni.putIfAbsent(_selectedDate, () => GiornoLavorativo());
  }
// Dentro _HomePageState
  Widget _customDayBuilder(BuildContext context, DateTime day, DateTime focusedDay) {
    final dataChiave = DateTime(day.year, day.month, day.day);
    final isLavorativo = _mappaTurnazione[dataChiave] ?? true;
    final isToday = isSameDay(day, DateTime.now());
    final isSelected = isSameDay(day, _selectedDate);

    Color? borderColor;
    if (isSelected) {
      borderColor = Colors.blue;
    } else if (isToday) {
      borderColor = Colors.orange;
    }

    Widget content = Text(
      '${day.day}',
      style: const TextStyle(
        fontSize: 18,
        color: Colors.black,
        height: 1.0,
      ),
      textAlign: TextAlign.center,
    );

    if (!isLavorativo) {
      content = Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color.fromARGB(76, 0, 128, 0),
          shape: BoxShape.circle,
        ),
        child: content,
      );
    }

    if (isToday || isSelected) {
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: 2),
        ),
        child: content,
      );
    }

    return Center(child: content);
  }

  @override
  void initState() {
    super.initState();

    _caricaGiorni();

    _caricaTurnazioneComeMappa().then((mappa) {
      setState(() {
        _mappaTurnazione = mappa;
      });
    });
  }
  Future<Map<DateTime, bool>> _caricaTurnazioneComeMappa() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('mappaGiorniTurno');
    if (jsonString == null) {
      debugPrint('⚠️ Nessuna mappa trovata nei salvataggi.');
      return {};
    }

    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    return {
      for (var entry in jsonData.entries)
        DateTime.parse(entry.key): entry.value as bool,
    };
  }

  Future<void> _caricaGiorni() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('giorniLavorativi');
    if (jsonString == null) return;

    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    _giorni.clear();

    jsonData.forEach((dataKey, valore) {
      final data = DateTime.parse(dataKey);
      _giorni[data] = GiornoLavorativo.fromJson(valore);
    });

    setState(() {});
  }

  Future<void> _salvaGiorni() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonData = {};

    _giorni.forEach((key, valore) {
      final dataKey = key.toIso8601String();
      jsonData[dataKey] = valore.toJson();
    });

    final jsonString = jsonEncode(jsonData);
    await prefs.setString('mappaGiorniTurno', jsonString);
  }

  void _apriDialogoInserimento() {
    final giorno = _oggi;
    final TextEditingController
    pausaController = // ignore: unused_local_variable
    TextEditingController(text: giorno.pausa.inMinutes.toString());
    final TextEditingController
    servizioController = // ignore: unused_local_variable
    TextEditingController(text: giorno.tipoServizio);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController inizioController = TextEditingController(
          text:
          giorno.inizio != null
              ? '${giorno.inizio!.hour.toString().padLeft(2, '0')}:${giorno.inizio!.minute.toString().padLeft(2, '0')}'
              : '',
        );
        final TextEditingController fineController = TextEditingController(
          text:
          giorno.fine != null
              ? '${giorno.fine!.hour.toString().padLeft(2, '0')}:${giorno.fine!.minute.toString().padLeft(2, '0')}'
              : '',
        );
        final TextEditingController pausaController = TextEditingController(
          text: giorno.pausa.inMinutes.toString(),
        );
        final TextEditingController servizioController = TextEditingController(
          text: giorno.tipoServizio,
        );

        return AlertDialog(
          title: const Text('Inserisci prestazione'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: inizioController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ora inizio (hh:mm)',
                  ),
                  onChanged: (value) {
                    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (numeric.length > 4) return;
                    String formatted = numeric;
                    if (numeric.length >= 3) {
                      formatted =
                      '${numeric.substring(0, 2)}:${numeric.substring(2)}';
                    }
                    inizioController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                    if (numeric.length == 4) {
                      final h = int.tryParse(numeric.substring(0, 2));
                      final m = int.tryParse(numeric.substring(2));
                      if (h != null &&
                          m != null &&
                          h >= 0 &&
                          h < 24 &&
                          m >= 0 &&
                          m < 60) {
                        setState(() {
                          giorno.inizio = TimeOfDay(hour: h, minute: m);
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fineController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ora fine (hh:mm)',
                  ),
                  onChanged: (value) {
                    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (numeric.length > 4) return;
                    String formatted = numeric;
                    if (numeric.length >= 3) {
                      formatted =
                      '${numeric.substring(0, 2)}:${numeric.substring(2)}';
                    }
                    fineController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                    if (numeric.length == 4) {
                      final h = int.tryParse(numeric.substring(0, 2));
                      final m = int.tryParse(numeric.substring(2));
                      if (h != null &&
                          m != null &&
                          h >= 0 &&
                          h < 24 &&
                          m >= 0 &&
                          m < 60) {
                        setState(() {
                          giorno.fine = TimeOfDay(hour: h, minute: m);
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pausaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pausa (minuti)',
                    floatingLabelStyle: TextStyle(fontSize: 12),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: servizioController,
                  decoration: const InputDecoration(labelText: 'Tipo servizio'),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Annulla'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Salva'),
              onPressed: () {
                if (giorno.inizio == null || giorno.fine == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inserisci ora inizio e ora fine'),
                    ),
                  );
                  return;
                }

                setState(() {
                  giorno.pausa = Duration(
                    minutes: int.tryParse(pausaController.text) ?? 0,
                  );
                  giorno.tipoServizio = servizioController.text;
                });

                _salvaGiorni();
                Navigator.of(context).pop();

                setState(() {
                  _selectedDate = _selectedDate;
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _apriImpostazioni() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
            SettingsPage(onScalaTestoCambiata: widget.onScalaTestoCambiata),
      ),
    );
  }

  String _formattaDurata(Duration durata) {
    final ore = durata.inHours;
    final minuti = durata.inMinutes.remainder(60);
    return "${ore}h ${minuti}min";
  }

  @override
  Widget build(BuildContext context) {
    final dataFormattata = DateFormat(
      'EEEE, dd MMMM yyyy',
      'it_IT',
    ).format(_selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text('OreExtra'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Text(
                dataFormattata,
                style: TextStyle(fontSize: 16, color: Colors.green.shade700),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: _apriImpostazioni,
                icon: const Icon(Icons.settings),
                label: const Text("Menù", style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: _apriDialogoInserimento,
                icon: const Icon(Icons.add),
                label: const Text(
                  "Inserisci prestazione",
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Ore totali: ${_formattaDurata(_oggi.durata)}",
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Straordinario: ${_formattaDurata(_oggi.straordinario)}",
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Pausa: ${_formattaDurata(_oggi.pausa)}",
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    "Tipo servizio: ${_oggi.tipoServizio.isEmpty ? '—' : _oggi.tipoServizio}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _salvaGiorni();
                          setState(() {
                            _selectedDate = DateTime.now();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Oggi"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: funzione risultati
                        },
                        icon: const Icon(Icons.bar_chart),
                        label: const Text("Risultati"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: funzione esporta
                        },
                        icon: const Icon(Icons.download),
                        label: const Text("Esporta"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),


            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
                child: SizedBox(
                  height: 400,
                  child: TableCalendar(
                    locale: 'it_IT',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2099, 12, 31),
                    focusedDay: _selectedDate,
                    selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                    onDaySelected: (selected, focused) async {
                      setState(() {
                        _selectedDate = selected;
                      });

                      await _salvaGiorni();

                      final nuovaMappa = await _caricaTurnazioneComeMappa();
                      setState(() {
                        _mappaTurnazione = nuovaMappa;
                      });
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: _customDayBuilder,
                      todayBuilder: _customDayBuilder,
                      selectedBuilder: _customDayBuilder,
                    ),

                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      leftChevronVisible: true,
                      rightChevronVisible: true,
                      headerPadding: const EdgeInsets.symmetric(horizontal: 8),
                      headerMargin: const EdgeInsets.only(bottom: 8),
                    ),

                    calendarStyle: CalendarStyle(
                      todayDecoration: const BoxDecoration(),
                      selectedDecoration: const BoxDecoration(),
                      defaultTextStyle: const TextStyle(fontSize: 18),
                      weekendTextStyle: const TextStyle(fontSize: 18),
                      todayTextStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      selectedTextStyle: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),

                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final void Function(TextScaleOption) onScalaTestoCambiata;

  const SettingsPage({super.key, required this.onScalaTestoCambiata});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TextScaleOption _selectedOption = TextScaleOption.normale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Impostazioni")),
      body: Column(
        children: [
          RadioListTile<TextScaleOption>(
            title: const Text('Normale'),
            value: TextScaleOption.normale,
            groupValue: _selectedOption,
            onChanged: (value) {
              setState(() {
                _selectedOption = value!;
              });
              widget.onScalaTestoCambiata(value!);
            },
          ),
          RadioListTile<TextScaleOption>(
            title: const Text('Medio'),
            value: TextScaleOption.medio,
            groupValue: _selectedOption,
            onChanged: (value) {
              setState(() {
                _selectedOption = value!;
              });
              widget.onScalaTestoCambiata(value!);
            },
          ),
          RadioListTile<TextScaleOption>(
            title: const Text('Grande'),
            value: TextScaleOption.grande,
            groupValue: _selectedOption,
            onChanged: (value) {
              setState(() {
                _selectedOption = value!;
              });
              widget.onScalaTestoCambiata(value!);
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.schedule),
            title: Text('Impostazioni Turnazione'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TurnazioneSettingsPage(),
                ),
              );
            },
          ),

        ],
      ),
    );
  }
}

class GiornoLavorativo {
  TimeOfDay? inizio;
  TimeOfDay? fine;
  Duration pausa;
  String tipoServizio;

  GiornoLavorativo({
    this.inizio,
    this.fine,
    this.pausa = Duration.zero,
    this.tipoServizio = '',
  });

  Duration get durata {
    if (inizio == null || fine == null) return Duration.zero;
    final start = DateTime(0, 0, 0, inizio!.hour, inizio!.minute);
    final end = DateTime(0, 0, 0, fine!.hour, fine!.minute);
    var diff = end.difference(start) - pausa;
    return diff.isNegative ? Duration.zero : diff;
  }

  Duration get straordinario {
    final ref = Duration(hours: 8);
    final extra = durata - ref;
    return extra.isNegative ? Duration.zero : extra;
  }

  Map<String, dynamic> toJson() {
    return {
      'inizio': inizio != null ? '${inizio!.hour}:${inizio!.minute}' : null,
      'fine': fine != null ? '${fine!.hour}:${fine!.minute}' : null,
      'pausa': pausa.inMinutes,
      'tipoServizio': tipoServizio,
    };
  }

  static GiornoLavorativo fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? time) {
      if (time == null) return null;
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return GiornoLavorativo(
      inizio: parseTime(json['inizio']),
      fine: parseTime(json['fine']),
      pausa: Duration(minutes: json['pausa'] ?? 0),
      tipoServizio: json['tipoServizio'] ?? '',
    );
  }
}
Future<Duration> calcolaStraordinario(GiornoLavorativo giorno) async {
  final prefs = await SharedPreferences.getInstance();
  final savedTime = prefs.getString('orarioStandard') ?? '08:00';
  final parts = savedTime.split(':');
  final ore = int.tryParse(parts[0]) ?? 8;
  final minuti = int.tryParse(parts[1]) ?? 0;
  final ref = Duration(hours: ore, minutes: minuti);

  final durata = giorno.durata;
  final extra = durata - ref;
  return extra.isNegative ? Duration.zero : extra;
}