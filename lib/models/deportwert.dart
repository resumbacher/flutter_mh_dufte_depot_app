class Depotwert {
  final String id;
  final String aktie;
  final String symbol; // statt wkn → für API-Ticker
  final double kaufkurs;
  final double? aktuellerKurs;

  Depotwert({
    required this.id,
    required this.aktie,
    required this.symbol,
    required this.kaufkurs,
    this.aktuellerKurs,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "aktie": aktie,
      "symbol": symbol,
      "kaufkurs": kaufkurs,
      "aktuellerKurs": aktuellerKurs,
    };
  }

  factory Depotwert.fromMap(Map<String, dynamic> map, String id) {
    return Depotwert(
      id: id,
      aktie: map["aktie"] ?? "",
      symbol: map["symbol"] ?? "",
      kaufkurs: (map["kaufkurs"] as num).toDouble(),
      aktuellerKurs: map["aktuellerKurs"] != null
          ? (map["aktuellerKurs"] as num).toDouble()
          : null,
    );
  }
}

