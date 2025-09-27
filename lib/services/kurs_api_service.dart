import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class KursApiService {
  static final String _apiKey = dotenv.env['ALPHAVANTAGE_API_KEY'] ?? '';
  static const String _baseUrl = "https://www.alphavantage.co/query";

  /// Aktueller Kurs eines Symbols
  static Future<double?> fetchAktuellerKurs(String symbol) async {
    if (_apiKey.isEmpty) {
      throw Exception("API-Key fehlt! Bitte .env Datei prüfen.");
    }

    final url = Uri.parse("$_baseUrl?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$_apiKey");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final preis = data["Global Quote"]?["05. price"];
      if (preis != null) {
        return double.tryParse(preis);
      }
    }
    return null;
  }

  /// Historische Tageskurse (adjusted close)
  static Future<Map<DateTime, double>> fetchHistorischeKurse(String symbol) async {
    if (_apiKey.isEmpty) {
      throw Exception("API-Key fehlt! Bitte .env Datei prüfen.");
    }

    final url = Uri.parse("$_baseUrl?function=TIME_SERIES_DAILY&symbol=$symbol&outputsize=full&apikey=$_apiKey");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      print("API Antwort: $data");

      if (data["Time Series (Daily)"] == null) {
        throw Exception("Keine historischen Daten gefunden.");
      }

      final Map<DateTime, double> kurse = {};
      (data["Time Series (Daily)"] as Map<String, dynamic>).forEach((datum, werte) {
        final preis = double.tryParse(werte["4. close"]);
        if (preis != null) {
          kurse[DateTime.parse(datum)] = preis;
        }
      });

      return kurse;
    } else {
      throw Exception("Fehler beim Laden historischer Kurse: ${response.statusCode}");
    }
  }
}


