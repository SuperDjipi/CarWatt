import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart' as csv_parser;
import 'package:latlong2/latlong.dart';
import '../database/database_helper.dart';
import '../models/station.dart';
import '../models/charge.dart';

class CsvImporter {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Map<int, int> _stationIdMapping = {}; // AJOUTER CETTE LIGNE

  /// Importe les stations depuis un fichier CSV
  Future<int> importStations(String filePath) async {
    final file = File(filePath);
    
    // Lire le fichier avec gestion d'encodage
    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (e) {
      try {
        content = await file.readAsString(encoding: latin1);
      } catch (e) {
        // Dernier recours : UTF-8 sans validation stricte
        final bytes = await file.readAsBytes();
        content = utf8.decode(bytes, allowMalformed: true); // CORRIGER ICI
      }
    }
    
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    
    // Parser avec tabulation
    final rows = csv_parser.CsvToListConverter(
      fieldDelimiter: '\t',
      eol: '\n', 
    ).convert(content);
    
    print('=== IMPORT STATIONS DEBUG ===');
    print('Nombre de lignes: ${rows.length}');
    if (rows.isNotEmpty) {
      print('En-têtes: ${rows[0]}');
    }
    
    int importCount = 0;
    
    // Ignorer la ligne d'en-tête (index 0)
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      
      print('Ligne $i: $row (${row.length} colonnes)');
      
      if (row.length < 6) {
        print('  -> Ignorée (pas assez de colonnes)');
        continue;
      }
      
      try {
        final latitude = row[2].toString().isEmpty ? null : double.parse(row[2].toString().replaceAll(',', '.'));
        final longitude = row[3].toString().isEmpty ? null : double.parse(row[3].toString().replaceAll(',', '.'));
        
        LatLng? position;
        if (latitude != null && longitude != null) {
          position = LatLng(latitude, longitude);
        }
        
        final reseaux = row[5].toString().split(';').where((r) => r.isNotEmpty).toList();
        
        final station = Station(
          nom: row[1].toString(),
          positionGps: position,
          adresse: row[4].toString().isEmpty ? null : row[4].toString(),
          reseaux: reseaux,
        );
        
        final id = await _db.insertStation(station);
        _stationIdMapping[int.parse(row[0].toString())] = id;
        importCount++;
        
        print('  -> Station importée avec succès (id: $id)');
      } catch (e) {
        print('  -> Erreur: $e');
      }
    }
    
    print('Import terminé: $importCount stations importées');
    return importCount;
  }

  /// Importe les charges depuis un fichier CSV
  Future<int> importCharges(String filePath, Map<int, int> stationIdMapping) async {
    final file = File(filePath);
    
    // Lire le fichier avec gestion d'encodage
    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (e) {
      try {
        content = await file.readAsString(encoding: latin1);
      } catch (e) {
        final bytes = await file.readAsBytes();
        content = utf8.decode(bytes, allowMalformed: true);
      }
    }
    
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    
    // Parser le CSV avec virgule comme séparateur
    final rows = csv_parser.CsvToListConverter(
      eol: '\n', 
    ).convert(content);
    
    print('=== IMPORT CHARGES DEBUG ===');
    print('Nombre de lignes: ${rows.length}');
    if (rows.isNotEmpty) {
      print('En-têtes: ${rows[0]}');
    }
    
    int importCount = 0;
    
    // Ignorer la ligne d'en-tête (index 0)
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      
      print('Ligne $i: $row (${row.length} colonnes)');
      
      if (row.length < 11) {
        print('  -> Ignorée (pas assez de colonnes)');
        continue;
      }
      
      try {
        // Déterminer le mode de saisie
        final inputModeStr = row[7].toString().replaceAll("'", "");
        final modeSaisie = inputModeStr == 'BY_AMOUNT' 
            ? ModeSaisie.montant 
            : ModeSaisie.prixKwh;
        
        // Déterminer le statut
        final statutStr = row.length > 10 ? row[10].toString() : 'COMPLETE';
        final statut = statutStr == 'DRAFT' ? StatutCharge.draft : StatutCharge.complete;
        
        // Mapper l'ancien ID de station vers le nouveau
        final oldStationId = row[3].toString().isEmpty ? null : int.parse(row[3].toString());
        final newStationId = oldStationId != null ? stationIdMapping[oldStationId] : null;
        
        // Parser tous les champs numériques
        final timestamp = int.parse(row[1].toString());
        final kilometrage = row[2].toString().isEmpty ? null : double.parse(row[2].toString().replaceAll(',', '.'));
        final jaugeDebut = double.parse(row[4].toString().replaceAll(',', '.'));
        final jaugeFin = double.parse(row[5].toString().replaceAll(',', '.'));
        final nbKwh = double.parse(row[6].toString().replaceAll(',', '.'));
        final paye = double.parse(row[8].toString().replaceAll(',', '.'));
        final prixE10 = row[9].toString().isEmpty ? null : double.parse(row[9].toString().replaceAll(',', '.'));
        
        final charge = Charge(
          horodatage: DateTime.fromMillisecondsSinceEpoch(timestamp),
          kilometrage: kilometrage,
          jaugeDebut: jaugeDebut,
          jaugeFin: jaugeFin,
          nbKwh: nbKwh,
          modeSaisie: modeSaisie,
          paye: paye,
          stationId: newStationId,
          prixE10: prixE10,
          statut: statut,
        );
        
        await _db.insertCharge(charge);
        importCount++;
        
        if (importCount % 10 == 0) {
          print('  -> $importCount charges importées...');
        }
      } catch (e) {
        print('  -> Erreur ligne ${i + 1}: $e');
      }
    }
    
    print('Import terminé: $importCount charges importées');
    return importCount;
  }

  /// Importe à la fois les stations et les charges
  Future<Map<String, int>> importAll(String stationsPath, String chargesPath) async {
    print('Début de l\'import complet...');
    
    // 1. Importer les stations
    final stationsCount = await importStations(stationsPath);
    
    // 2. Importer les charges avec le mapping des IDs de stations
    final chargesCount = await importCharges(chargesPath, _stationIdMapping);
    
    return {
      'stations': stationsCount,
      'charges': chargesCount,
    };
  }

  // Méthodes utilitaires pour parser les nombres de façon robuste
  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(',', '.').trim();
      return double.parse(cleaned);
    }
    throw FormatException('Cannot parse $value as double');
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.parse(value.trim());
    }
    throw FormatException('Cannot parse $value as int');
  }
}