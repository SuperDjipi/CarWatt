class Parametre {
  final int? id;
  final String nom;
  final String? valeur; // Pour texte/nombre simple
  final double? valeurNum; // Pour valeurs numériques
  final int? valeurDate; // Pour dates (timestamp)

  Parametre({
    this.id,
    required this.nom,
    this.valeur,
    this.valeurNum,
    this.valeurDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'valeur': valeur,
      'valeur_num': valeurNum,
      'valeur_date': valeurDate,
    };
  }

  factory Parametre.fromMap(Map<String, dynamic> map) {
    return Parametre(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      valeur: map['valeur'] as String?,
      valeurNum: map['valeur_num'] as double?,
      valeurDate: map['valeur_date'] as int?,
    );
  }

  Parametre copyWith({
    int? id,
    String? nom,
    String? valeur,
    double? valeurNum,
    int? valeurDate,
  }) {
    return Parametre(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      valeur: valeur ?? this.valeur,
      valeurNum: valeurNum ?? this.valeurNum,
      valeurDate: valeurDate ?? this.valeurDate,
    );
  }
}
