class Trajet {
  final int? id;
  final DateTime date;
  final int rechargeDepart; // ID de la recharge de départ
  final int rechargeArrivee; // ID de la recharge d'arrivée
  final double qtEnergiePercent; // Quantité d'énergie consommée en %

  Trajet({
    this.id,
    required this.date,
    required this.rechargeDepart,
    required this.rechargeArrivee,
    required this.qtEnergiePercent,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'recharge_depart': rechargeDepart,
      'recharge_arrivee': rechargeArrivee,
      'qt_energie_percent': qtEnergiePercent,
    };
  }

  factory Trajet.fromMap(Map<String, dynamic> map) {
    return Trajet(
      id: map['id'] as int?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      rechargeDepart: map['recharge_depart'] as int,
      rechargeArrivee: map['recharge_arrivee'] as int,
      qtEnergiePercent: map['qt_energie_percent'] as double,
    );
  }

  Trajet copyWith({
    int? id,
    DateTime? date,
    int? rechargeDepart,
    int? rechargeArrivee,
    double? qtEnergiePercent,
  }) {
    return Trajet(
      id: id ?? this.id,
      date: date ?? this.date,
      rechargeDepart: rechargeDepart ?? this.rechargeDepart,
      rechargeArrivee: rechargeArrivee ?? this.rechargeArrivee,
      qtEnergiePercent: qtEnergiePercent ?? this.qtEnergiePercent,
    );
  }

  // Label pour affichage
  String get label => '${_formatDate(date)} - $qtEnergiePercent %';

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
