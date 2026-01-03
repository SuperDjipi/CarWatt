import 'package:latlong2/latlong.dart';

class Station {
  final int? id;
  final String nom;
  final LatLng? positionGps;
  final String? adresse;
  final List<String> reseaux; // Liste des réseaux (Ionity, Tesla, etc.)

  Station({
    this.id,
    required this.nom,
    this.positionGps,
    this.adresse,
    this.reseaux = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'latitude': positionGps?.latitude,
      'longitude': positionGps?.longitude,
      'adresse': adresse,
      'reseaux': reseaux.join(','), // Stockage CSV
    };
  }

  factory Station.fromMap(Map<String, dynamic> map) {
    LatLng? position;
    if (map['latitude'] != null && map['longitude'] != null) {
      position = LatLng(
        map['latitude'] as double,
        map['longitude'] as double,
      );
    }

    return Station(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      positionGps: position,
      adresse: map['adresse'] as String?,
      reseaux: map['reseaux'] != null && (map['reseaux'] as String).isNotEmpty
          ? (map['reseaux'] as String).split(',')
          : [],
    );
  }

  Station copyWith({
    int? id,
    String? nom,
    LatLng? positionGps,
    String? adresse,
    List<String>? reseaux,
  }) {
    return Station(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      positionGps: positionGps ?? this.positionGps,
      adresse: adresse ?? this.adresse,
      reseaux: reseaux ?? this.reseaux,
    );
  }

  // Calcul de distance depuis une position donnée
  double? distanceFrom(LatLng? currentPosition) {
    if (currentPosition == null || positionGps == null) return null;
    
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, currentPosition, positionGps!);
  }
}
