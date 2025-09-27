import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_mh_dufte_depot_app/services/kurs_api_service.dart';
import 'screens/detail_screen.dart';
import 'package:flutter_mh_dufte_depot_app/models/depotwert.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");
  runApp(const DepotApp());
}

// ----------------------------------------------------------------------
// Rumpf der App (App Shell)
// ----------------------------------------------------------------------
class DepotApp extends StatelessWidget {
  const DepotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Depot Verwaltung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.blueGrey,
        ),
      ),
      home: const DepotHomePage(),
    );
  }
}

// ----------------------------------------------------------------------
// Hauptübersichtsseite des Depots mit Gesamtwertberechnung
// ----------------------------------------------------------------------
class DepotHomePage extends StatefulWidget {
  const DepotHomePage({super.key});

  @override
  State<DepotHomePage> createState() => _DepotHomePageState();
}

class _DepotHomePageState extends State<DepotHomePage> {
  void _openAddDialog({Depotwert? wert}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDepotPage(editWert: wert),
      ),
    );
  }

  void _deleteDepotwert(String id) async {
    await FirebaseFirestore.instance.collection('depotwerte').doc(id).delete();
  }

  // Hilfsfunktion zur Berechnung der Gesamtsummen
  Map<String, double> _calculateTotals(List<Depotwert> werte) {
    double totalValue = 0.0;
    double totalCost = 0.0;

    for (var wert in werte) {
      totalValue += wert.tageskurs * wert.stueck;
      totalCost += wert.kaufsumme;
    }

    double totalProfitLoss = totalValue - totalCost;

    return {
      'totalValue': totalValue,
      'totalProfitLoss': totalProfitLoss,
    };
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      color: Colors.grey[900],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Depot Übersicht')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('depotwerte').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          final List<Depotwert> depotwerte = docs
              .map((doc) =>
                  Depotwert.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          final totals = _calculateTotals(depotwerte);
          final totalValue = totals['totalValue']!;
          final totalProfitLoss = totals['totalProfitLoss']!;
          final profitLossColor =
              totalProfitLoss >= 0 ? Colors.greenAccent : Colors.redAccent;
          final profitLossPercentage =
              (totalProfitLoss / (totalValue - totalProfitLoss).abs() * 100);
          final profitLossText = totalProfitLoss >= 0 ? '+' : '';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    _buildSummaryCard(
                      'Gesamtwert',
                      '${totalValue.toStringAsFixed(2)} €',
                      Colors.blueAccent,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryCard(
                      'Gesamt G/V (Absolut)',
                      '$profitLossText${totalProfitLoss.toStringAsFixed(2)} €',
                      profitLossColor,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryCard(
                      'Gesamt G/V (Prozent)',
                      '$profitLossText${profitLossPercentage.toStringAsFixed(1)} %',
                      profitLossColor,
                    ),
                    const Divider(color: Colors.white54),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: depotwerte.length,
                  itemBuilder: (context, index) {
                    final wert = depotwerte[index];

                    return ListTile(
                      tileColor: Colors.grey[900],
                      title: Text(
                        "${wert.aktie} (${wert.wkn})",
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "Kurs: ${wert.tageskurs.toStringAsFixed(2)} € | "
                        "G/V: ${wert.gewinnVerlust.toStringAsFixed(2)} € "
                        "(${wert.gewinnVerlustProzent.toStringAsFixed(1)}%)",
                        style: TextStyle(
                          color: wert.gewinnVerlust >= 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(wert: wert),
                          ),
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        color: Colors.grey[850],
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openAddDialog(wert: wert);
                          } else if (value == 'delete') {
                            _deleteDepotwert(wert.id!);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'edit',
                              child: Text('Bearbeiten',
                                  style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Text('Löschen',
                                  style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () => _openAddDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// AddDepotPage bleibt wie gehabt (nur Speichern in Firestore)
// ----------------------------------------------------------------------

class AddDepotPage extends StatefulWidget {
  final Depotwert? editWert;
  const AddDepotPage({super.key, this.editWert});

  @override
  State<AddDepotPage> createState() => _AddDepotPageState();
}

class _AddDepotPageState extends State<AddDepotPage> {
  final _formKey = GlobalKey<FormState>();
  final _wknController = TextEditingController();
  final _aktieController = TextEditingController();
  final _preisController = TextEditingController();
  final _stueckController = TextEditingController();
  final _tageskursController = TextEditingController();
  final _kostenController = TextEditingController();
  DateTime _kaufdatum = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.editWert != null) {
      final w = widget.editWert!;
      _wknController.text = w.wkn;
      _aktieController.text = w.aktie;
      _preisController.text = w.preis.toString();
      _stueckController.text = w.stueck.toString();
      _tageskursController.text = w.tageskurs.toString();
      _kostenController.text = w.kosten.toString();
      _kaufdatum = w.datum;
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'wkn': _wknController.text,
        'aktie': _aktieController.text,
        'stueck': int.parse(_stueckController.text),
        'preis': double.parse(_preisController.text),
        'tageskurs': double.parse(_tageskursController.text),
        'kosten': double.tryParse(_kostenController.text) ?? 0,
        'datum': _kaufdatum.toIso8601String(),
      };

      if (widget.editWert == null) {
        await FirebaseFirestore.instance.collection('depotwerte').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('depotwerte')
            .doc(widget.editWert!.id)
            .update(data);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _fetchFromApi() async {
    final kurs =
        await KursApiService.fetchAktuellerKurs(_wknController.text.trim());
    if (kurs != null) {
      setState(() {
        _tageskursController.text = kurs.toStringAsFixed(2);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kurs konnte nicht geladen werden.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.editWert == null
              ? "Neuer Depotwert"
              : "Depotwert bearbeiten")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _wknController,
                decoration: const InputDecoration(labelText: "Ticker"),
                style: const TextStyle(color: Colors.white),
              ),
              TextFormField(
                controller: _aktieController,
                decoration: const InputDecoration(labelText: "Aktie"),
                style: const TextStyle(color: Colors.white),
              ),
              TextFormField(
                controller: _stueckController,
                decoration: const InputDecoration(labelText: "Stück"),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
              ),
              TextFormField(
                controller: _preisController,
                decoration: const InputDecoration(labelText: "Kaufpreis (€)"),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tageskursController,
                      decoration: const InputDecoration(
                          labelText: "Aktueller Kurs (€)"),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _fetchFromApi,
                    child: const Text("API laden"),
                  ),
                ],
              ),
              TextFormField(
                controller: _kostenController,
                decoration: const InputDecoration(
                    labelText: "Transaktionskosten (€)"),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                child: Text(
                    "Kaufdatum auswählen: ${_kaufdatum.toLocal().toString().split(' ')[0]}"),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _kaufdatum,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _kaufdatum = picked);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                child: const Text("Speichern"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Datenmodell
// ----------------------------------------------------------------------

class Depotwert {
  final String? id;
  final String wkn;
  final String aktie;
  final int stueck;
  final double preis;
  final double tageskurs;
  final double kosten;
  final DateTime datum;

  Depotwert({
    this.id,
    required this.wkn,
    required this.aktie,
    required this.stueck,
    required this.preis,
    required this.tageskurs,
    required this.kosten,
    required this.datum,
  });

  double get kaufsumme => stueck * preis + kosten;

  double get gewinnVerlust => (tageskurs - preis) * stueck - kosten;

  double get gewinnVerlustProzent => ((tageskurs - preis) / preis) * 100;

  factory Depotwert.fromMap(Map<String, dynamic> data, String id) {
    return Depotwert(
      id: id,
      wkn: data['wkn'] ?? '',
      aktie: data['aktie'] ?? '',
      stueck: (data['stueck'] as num?)?.toInt() ?? 0,
      preis: (data['preis'] as num?)?.toDouble() ?? 0.0,
      tageskurs: (data['tageskurs'] as num?)?.toDouble() ?? 0.0,
      kosten: (data['kosten'] as num?)?.toDouble() ?? 0.0,
      datum: DateTime.parse(data['datum'] ?? DateTime.now().toIso8601String()),
    );
  }
}
