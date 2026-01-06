import 'package:latlong2/latlong.dart';

enum TypeTrajet {
  auto,   // Calculé automatiquement entre deux charges
  manual, // Saisi manuellement
}

class Trajet {
  final int? id;
  final DateTime date;
  final int? rechargeDepart;  // Nullable car trajet manuel peut ne pas avoir de charge associée
  final int? rechargeArrivee; // Nullable aussi
  final double qtEnergiePercent;
  final TypeTrajet type; // AJOUTER CE CHAMP

  // Pour les trajets manuels sans charges
  final String? lieuDepart;
  final String? lieuArrivee;
  final double? jaugeDepartPercent;
  final double? jaugeArriveePercent;
  final double? kilometrageDepart;
  final double? kilometrageArrivee;

  Trajet({
    this.id,
    required this.date,
    this.rechargeDepart,
    this.rechargeArrivee,
    required this.qtEnergiePercent,
    this.type = TypeTrajet.auto,
    this.lieuDepart,
    this.lieuArrivee,
    this.jaugeDepartPercent,
    this.jaugeArriveePercent,
    this.kilometrageDepart,
    this.kilometrageArrivee,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'recharge_depart': rechargeDepart,
      'recharge_arrivee': rechargeArrivee,
      'qt_energie_percent': qtEnergiePercent,
      'type': type.name,
      'lieu_depart': lieuDepart,
      'lieu_arrivee': lieuArrivee,
      'jauge_depart_percent': jaugeDepartPercent,
      'jauge_arrivee_percent': jaugeArriveePercent,
      'kilometrage_depart': kilometrageDepart,
      'kilometrage_arrivee': kilometrageArrivee,
    };
  }

  factory Trajet.fromMap(Map<String, dynamic> map) {
    return Trajet(
      id: map['id'] as int?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      rechargeDepart: map['recharge_depart'] as int?,
      rechargeArrivee: map['recharge_arrivee'] as int?,
      qtEnergiePercent: map['qt_energie_percent'] as double,
      type: TypeTrajet.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TypeTrajet.auto,
      ),
      lieuDepart: map['lieu_depart'] as String?,
      lieuArrivee: map['lieu_arrivee'] as String?,
      jaugeDepartPercent: map['jauge_depart_percent'] as double?,
      jaugeArriveePercent: map['jauge_arrivee_percent'] as double?,
      kilometrageDepart: map['kilometrage_depart'] as double?,
      kilometrageArrivee: map['kilometrage_arrivee'] as double?,
    );
  }

  // Méthodes utiles
  bool get isAuto => type == TypeTrajet.auto;
  bool get isManual => type == TypeTrajet.manual;

  double? get distance {
    if (kilometrageDepart != null && kilometrageArrivee != null) {
      return kilometrageArrivee! - kilometrageDepart!;
    }
    return null;
  }

  double? get consoKwhAu100 {
    final dist = distance;
    if (dist != null && dist > 0) {
      // Capacité batterie par défaut 64 kWh (à récupérer des paramètres idéalement)
      const capaciteBatterie = 64.0;
      final energieConsommee = qtEnergiePercent / 100 * capaciteBatterie;
      return energieConsommee / dist * 100;
    }
    return null;
  }

  Trajet copyWith({
    int? id,
    DateTime? date,
    int? rechargeDepart,
    int? rechargeArrivee,
    double? qtEnergiePercent,
    TypeTrajet? type,
    String? lieuDepart,
    String? lieuArrivee,
    double? jaugeDepartPercent,
    double? jaugeArriveePercent,
    double? kilometrageDepart,
    double? kilometrageArrivee,
  }) {
    return Trajet(
      id: id ?? this.id,
      date: date ?? this.date,
      rechargeDepart: rechargeDepart ?? this.rechargeDepart,
      rechargeArrivee: rechargeArrivee ?? this.rechargeArrivee,
      qtEnergiePercent: qtEnergiePercent ?? this.qtEnergiePercent,
      type: type ?? this.type,
      lieuDepart: lieuDepart ?? this.lieuDepart,
      lieuArrivee: lieuArrivee ?? this.lieuArrivee,
      jaugeDepartPercent: jaugeDepartPercent ?? this.jaugeDepartPercent,
      jaugeArriveePercent: jaugeArriveePercent ?? this.jaugeArriveePercent,
      kilometrageDepart: kilometrageDepart ?? this.kilometrageDepart,
      kilometrageArrivee: kilometrageArrivee ?? this.kilometrageArrivee,
    );
  }

  String get label {
    final depart = lieuDepart ?? 'Départ';
    final arrivee = lieuArrivee ?? 'Arrivée';
    return '$depart → $arrivee';
  }

  String _formatDate() {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}