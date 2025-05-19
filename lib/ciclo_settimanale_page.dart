import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CalendarioCicloTestPage extends StatefulWidget {
  const CalendarioCicloTestPage({super.key});

  @override
  State<CalendarioCicloTestPage> createState() => _CalendarioCicloTestPageState();
}

class _CalendarioCicloTestPageState extends State<CalendarioCicloTestPage> {
  Map<String, int> mappaCiclo = {};
  List<String> etichette = [];

  final List<Color> colori = [
    Colors.purple,
    Colors.yellow.shade700,
    Colors.red.shade300,
    Colors.lightBlue
  ];

  @override
  void initState() {
    super.initState();
    _caricaCiclo();
  }

  Future<void> _caricaCiclo() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('mappaCicloSettimana');
    final listaEtichette = prefs.getStringList('etichetteCicloSettimana');

    if (jsonString != null && listaEtichette != null) {
      final Map<String, dynamic> raw = jsonDecode(jsonString);
      setState(() {
        mappaCiclo = raw.map((k, v) => MapEntry(k, v as int));
        etichette = listaEtichette;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final inizioMese = DateTime(today.year, today.month, 1);
    final fineMese = DateTime(today.year, today.month + 1, 0);

    return Scaffold(
      appBar: AppBar(title: const Text("Test Ciclo Settimanale")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: fineMese.day,
          itemBuilder: (context, index) {
            final giorno = inizioMese.add(Duration(days: index));
            final key = giorno.toIso8601String().split("T")[0];
            final indexCiclo = mappaCiclo[key];

            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${giorno.day}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (indexCiclo != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 6,
                      height: 30,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: colori[indexCiclo % colori.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  )
              ],
            );
          },
        ),
      ),
    );
  }
}
