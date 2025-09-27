import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/kurs_api_service.dart';

class DepotEingabeForm extends StatefulWidget {
  const DepotEingabeForm({super.key});

  @override
  State<DepotEingabeForm> createState() => _DepotEingabeFormState();
}

class _DepotEingabeFormState extends State<DepotEingabeForm> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _kursController = TextEditingController();
  final _stueckController = TextEditingController();
  final _preisController = TextEditingController();
  DateTime? _kaufDatum;
  bool _isLoading = false;

  Future<void> _ladeKursVonApi() async {
    setState(() => _isLoading = true);
    final kurs = await KursApiService.fetchAktuellerKurs(_symbolController.text.trim());
    setState(() => _isLoading = false);

    if (kurs != null) {
      setState(() {
        _kursController.text = kurs.toStringAsFixed(2);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kurs gefunden: ${kurs.toStringAsFixed(2)} €")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kein Kurs gefunden – bitte manuell eingeben")),
      );
    }
  }

  Future<void> _speichern() async {
    if (_formKey.currentState!.validate()) {
      final symbol = _symbolController.text.trim();
      final kurs = double.tryParse(_kursController.text) ?? 0.0;
      final stueck = int.tryParse(_stueckController.text) ?? 0;
      final preis = double.tryParse(_preisController.text) ?? 0.0;
      final kaufDatum = _kaufDatum ?? DateTime.now();

      final kaufSumme = preis * stueck;
      final kosten = kaufSumme * 0.01; // Dummy Transaktionskosten 1%

      try {
        await FirebaseFirestore.instance.collection("depotwerte").add({
          "symbol": symbol,
          "kurs": kurs,
          "stueck": stueck,
          "preis": preis,
          "kaufsumme": kaufSumme,
          "kosten": kosten,
          "datum": kaufDatum.toIso8601String(),
          "erstelltAm": DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Depotwert gespeichert ✅")),
          );
          Navigator.pop(context); // zurück zur Übersicht
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler beim Speichern: $e")),
        );
      }
    }
  }

  Future<void> _waehleDatum() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _kaufDatum = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Neuen Depotwert eingeben")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _symbolController,
                decoration: const InputDecoration(labelText: "Aktien-Ticker (z. B. AAPL, MSFT, BMW.DE)"),
                validator: (v) => v == null || v.isEmpty ? "Bitte Ticker eingeben" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Aktueller Kurs (€)"),
                validator: (v) => v == null || v.isEmpty ? "Bitte Kurs eingeben" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stueckController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Stück"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _preisController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Kaufpreis pro Stück (€)"),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _kaufDatum == null
                          ? "Kein Kaufdatum gewählt"
                          : "Kaufdatum: ${_kaufDatum!.toLocal().toString().split(' ')[0]}",
                    ),
                  ),
                  IconButton(
                    onPressed: _waehleDatum,
                    icon: const Icon(Icons.calendar_today),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _ladeKursVonApi,
                      icon: const Icon(Icons.cloud_download),
                      label: _isLoading
                          ? const Text("Lade...")
                          : const Text("Kurs von API"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _speichern,
                      icon: const Icon(Icons.save),
                      label: const Text("Speichern"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
