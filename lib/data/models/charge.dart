import 'package:latlong2/latlong.dart';

enum ModeSaisie {
  montant, // Saisie du montant total
  prixKwh, // Saisie du prix au kWh
}

enum StatutCharge {
  draft,    // Brouillon - charge incomplète
  complete, // Charge complète
}

class Charge {
  final int? id;
  final DateTime horodatage;
  final double? kilometrage;
  final double jaugeDebut; // Pourcentage 0-100
  final double jaugeFin; // Pourcentage 0-100
  final double nbKwh;
  final ModeSaisie modeSaisie;
  final double paye; // Montant payé
  final double? prixAuKwh; // Calculé si mode_saisie = montant
  final double? prixE10; // Snapshot du prix E10 au moment de la recharge
  final int? stationId;
  final StatutCharge statut;

  // Champs calculés stockés
  final double? prixPondere;
  final double? distance;
  final double? consoBatterie;
  final double? consoKwhAu100;
  final double? consoEssence;
  final double? economieTotale;
  final double? economieAu100;
  final double? chargePertesPct;

  // Champs relationnels (non stockés en DB, récupérés via jointure)
  final String? stationNom;
  final LatLng? stationPosition;

  Charge({
    this.id,
    required this.horodatage,
    this.kilometrage,
    required this.jaugeDebut,
    required this.jaugeFin,
    required this.nbKwh,
    this.modeSaisie = ModeSaisie.montant,
    required this.paye,
    this.prixAuKwh,
    this.prixE10,
    this.stationId,
    this.statut = StatutCharge.complete, 
    this.prixPondere,
    this.distance,
    this.consoBatterie,
    this.consoKwhAu100,
    this.consoEssence,
    this.economieTotale,
    this.economieAu100,
    this.chargePertesPct,
    this.stationNom,
    this.stationPosition,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'horodatage': horodatage.millisecondsSinceEpoch,
      'kilometrage': kilometrage,
      'jauge_debut': jaugeDebut,
      'jauge_fin': jaugeFin,
      'nb_kwh': nbKwh,
      'mode_saisie': modeSaisie.name,
      'paye': paye,
      'prix_au_kwh': prixAuKwh,
      'prix_e10': prixE10,
      'station_id': stationId,
      'statut': statut.name,
      'prix_pondere': prixPondere,
      'distance': distance,
      'conso_batterie': consoBatterie,
      'conso_kwh_au_100': consoKwhAu100,
      'conso_essence': consoEssence,
      'economie_totale': economieTotale,
      'economie_au_100': economieAu100,
      'charge_pertes_pct': chargePertesPct,
    };
  }

  factory Charge.fromMap(Map<String, dynamic> map) {
    LatLng? position;
    if (map['station_latitude'] != null && map['station_longitude'] != null) {
      position = LatLng(
        map['station_latitude'] as double,
        map['station_longitude'] as double,
      );
    }

    return Charge(
      id: map['id'] as int?,
      horodatage: DateTime.fromMillisecondsSinceEpoch(map['horodatage'] as int),
      kilometrage: map['kilometrage'] as double?,
      jaugeDebut: map['jauge_debut'] as double,
      jaugeFin: map['jauge_fin'] as double,
      nbKwh: map['nb_kwh'] as double,
      modeSaisie: ModeSaisie.values.firstWhere(
        (e) => e.name == map['mode_saisie'],
        orElse: () => ModeSaisie.montant,
      ),
      paye: map['paye'] as double,
      prixAuKwh: map['prix_au_kwh'] as double?,
      prixE10: map['prix_e10'] as double?,
      stationId: map['station_id'] as int?,
      statut: StatutCharge.values.firstWhere( 
        (e) => e.name == map['statut'],
        orElse: () => StatutCharge.complete,
      ),
      prixPondere: map['prix_pondere'] as double?,
      distance: map['distance'] as double?,
      consoBatterie: map['conso_batterie'] as double?,
      consoKwhAu100: map['conso_kwh_au_100'] as double?,
      consoEssence: map['conso_essence'] as double?,
      economieTotale: map['economie_totale'] as double?,
      economieAu100: map['economie_au_100'] as double?,
      chargePertesPct: map['charge_pertes_pct'] as double?,
      stationNom: map['station_nom'] as String?,
      stationPosition: position,
    );
  }

  Charge copyWith({
    int? id,
    DateTime? horodatage,
    double? kilometrage,
    double? jaugeDebut,
    double? jaugeFin,
    double? nbKwh,
    ModeSaisie? modeSaisie,
    double? paye,
    double? prixAuKwh,
    double? prixE10,
    int? stationId,
    StatutCharge? statut,
    double? prixPondere,
    double? distance,
    double? consoBatterie,
    double? consoKwhAu100,
    double? consoEssence,
    double? economieTotale,
    double? economieAu100,
    double? chargePertesPct,
    String? stationNom,
    LatLng? stationPosition,
  }) {
    return Charge(
      id: id ?? this.id,
      horodatage: horodatage ?? this.horodatage,
      kilometrage: kilometrage ?? this.kilometrage,
      jaugeDebut: jaugeDebut ?? this.jaugeDebut,
      jaugeFin: jaugeFin ?? this.jaugeFin,
      nbKwh: nbKwh ?? this.nbKwh,
      modeSaisie: modeSaisie ?? this.modeSaisie,
      paye: paye ?? this.paye,
      prixAuKwh: prixAuKwh ?? this.prixAuKwh,
      prixE10: prixE10 ?? this.prixE10,
      stationId: stationId ?? this.stationId,
      statut: statut ?? this.statut,
      prixPondere: prixPondere ?? this.prixPondere,
      distance: distance ?? this.distance,
      consoBatterie: consoBatterie ?? this.consoBatterie,
      consoKwhAu100: consoKwhAu100 ?? this.consoKwhAu100,
      consoEssence: consoEssence ?? this.consoEssence,
      economieTotale: economieTotale ?? this.economieTotale,
      economieAu100: economieAu100 ?? this.economieAu100,
      chargePertesPct: chargePertesPct ?? this.chargePertesPct,
      stationNom: stationNom ?? this.stationNom,
      stationPosition: stationPosition ?? this.stationPosition,
    );
  }

  bool get isDraft => statut == StatutCharge.draft;
  bool get isComplete => statut == StatutCharge.complete;
}
