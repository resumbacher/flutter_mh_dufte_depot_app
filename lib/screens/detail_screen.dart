import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_mh_dufte_depot_app/services/kurs_api_service.dart';
import 'package:flutter_mh_dufte_depot_app/models/depotwert.dart';

class DetailScreen extends StatefulWidget {
  final Depotwert wert;

  const DetailScreen({super.key, required this.wert});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  List<KursDaten> _historischeKurse = [];
  bool _loading = false;
  bool _kursLadenFehler = false;

  @override
  void initState() {
    super.initState();
    _ladeKurse();
    _ladeAktuellenKurs();
  }

  Future<void> _ladeKurse() async {
    setState(() {
      _loading = true;
      _kursLadenFehler = false;
    });

    final docRef = FirebaseFirestore.instance
        .collection("depotwerte")
        .doc(widget.wert.id);

    try {
      final snapshot = await docRef.collection("kurse").get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _historischeKurse = snapshot.docs.map((d) {
            final data = d.data();
            return KursDaten(
              d.id,
              (data["close"] as num).toDouble(),
            );
          }).toList()
            ..sort((a, b) => a.monat.compareTo(b.monat));
        });
      } else {
        // 🔹 Falls keine Kursdaten → API laden
        final kurse = await KursApiService.fetchHistorischeKurse(widget.wert.symbol);

        // In Firestore speichern
        for (var entry in kurse.entries) {
          await docRef
              .collection("kurse")
              .doc(entry.key.toIso8601String().split("T")[0])
              .set({"close": entry.value});
        }

        setState(() {
          _historischeKurse = kurse.entries.map((e) {
            return KursDaten(
                e.key.toIso8601String().split("T")[0], e.value);
          }).toList()
            ..sort((a, b) => a.monat.compareTo(b.monat));
        });
      }
    } catch (e) {
      setState(() {
        _kursLadenFehler = true;
      });
    }

    setState(() => _loading = false);
  }

  Future<void> _ladeAktuellenKurs() async {
    try {
      final kurs = await KursApiService.fetchAktuellerKurs(widget.wert.symbol);
      if (kurs != null) {
        await FirebaseFirestore.instance
            .collection("depotwerte")
            .doc(widget.wert.id)
            .update({"aktuellerKurs": kurs});
        setState(() {
          widget.wert.aktuellerKurs = kurs;
        });
      }
    } catch (_) {
      // Fehler ignorieren, Anzeige bleibt unverändert
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Details: ${widget.wert.aktie}")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _kursLadenFehler
              ? const Center(
                  child: Text(
                    "Kursdaten konnten nicht geladen werden",
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : _historischeKurse.isEmpty
                  ? const Center(
                      child: Text(
                        "Keine Kursdaten verfügbar",
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Aktueller Kurs: ${widget.wert.aktuellerKurs?.toStringAsFixed(2) ?? "-"} €",
                            style: const TextStyle(
                                fontSize: 20, color: Colors.white),
                          ),
                        ),
                        Expanded(
                          child: SfCartesianChart(
                            backgroundColor: Colors.black,
                            title: ChartTitle(
                              text: "Kursentwicklung",
                              textStyle: const TextStyle(color: Colors.white),
                            ),
                            primaryXAxis: CategoryAxis(
                              labelStyle:
                                  const TextStyle(color: Colors.white),
                              axisLine:
                                  const AxisLine(color: Colors.white54),
                              majorGridLines:
                                  const MajorGridLines(color: Colors.white24),
                            ),
                            primaryYAxis: NumericAxis(
                              labelStyle:
                                  const TextStyle(color: Colors.white),
                              axisLine:
                                  const AxisLine(color: Colors.white54),
                              majorGridLines:
                                  const MajorGridLines(color: Colors.white24),
                            ),
                            series: <CartesianSeries>[
                              LineSeries<KursDaten, String>(
                                dataSource: _historischeKurse,
                                xValueMapper: (d, _) => d.monat,
                                yValueMapper: (d, _) => d.kurs,
                                color: Colors.blueAccent,
                                markerSettings: const MarkerSettings(
                                  isVisible: true,
                                  color: Colors.blueAccent,
                                  borderColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _ladeKurse();
          _ladeAktuellenKurs();
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class KursDaten {
  final String monat;
  final double kurs;

  KursDaten(this.monat, this.kurs);
}

