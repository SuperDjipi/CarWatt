import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart' as csv_parser;
import 'package:latlong2/latlong.dart';
import '../database/database_helper.dart';
import '../models/station.dart';
import '../models/charge.dart';

class CsvImporter {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Importe les stations depuis un fichier CSV
  /// Format attendu: Id, name, latitude, longitude, address, network
  /// Retourne un Map des anciens IDs vers les nouveaux IDs
  Future<Map<int, int>> importStations(String filePath) async {
    final file = File(filePath);
    // Essayer plusieurs encodages
    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (e) {
      // Si UTF-8 échoue, essayer Latin1
      try {
        content = await file.readAsString(encoding: latin1);
      } catch (e2) {
        // Dernier recours : lire les bytes et ignorer les erreurs
        final bytes = await file.readAsBytes();
        content = utf8.decode(bytes, allowMalformed: true);
      }
    }
    
    // Parser le CSV avec tabulation comme séparateur
    final rows = csv_parser.CsvToListConverter(fieldDelimiter: '\t').convert(content);
    
    Map<int, int> idMapping = {};
    
    // Ignorer la ligne d'en-tête (index 0)
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 6) continue; // Vérifier qu'on a assez de colonnes
      
      try {
        final oldId = _parseInt(row[0]);
        
        final station = Station(
          nom: row[1].toString(),
          positionGps: LatLng(
            _parseDouble(row[2]),
            _parseDouble(row[3]),
          ),
          adresse: row[4].toString(),
          reseaux: [row[5].toString()],
        );
        
        final newId = await _db.insertStation(station);
        idMapping[oldId] = newId;
      } catch (e) {
        print('Erreur ligne ${i + 1}: $e');
      }
    }
    
    return idMapping;
  }

  /// Importe les charges depuis un fichier CSV
  /// Format attendu: id,timestamp,mileage,stationId,startChargePercentage,endChargePercentage,kwhAmount,inputMode,amountPaid,e10Price
  Future<int> importCharges(String filePath, Map<int, int> stationIdMapping) async {
    final file = File(filePath);
    final content = await file.readAsString();
  
    // Parser le CSV avec virgule comme séparateur
    final rows = csv_parser.CsvToListConverter().convert(content);
  
    int importCount = 0;
  
    // Ignorer la ligne d'en-tête (index 0)
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 10) continue; // Vérifier qu'on a assez de colonnes
    
      try {
        // Déterminer le mode de saisie
        final inputModeStr = row[7].toString().replaceAll("'", "");
        final modeSaisie = inputModeStr == 'BY_AMOUNT' 
            ? ModeSaisie.montant 
            : ModeSaisie.prixKwh;
      
        // Mapper l'ancien ID de station vers le nouveau
        final oldStationId = _parseInt(row[3]);
        final newStationId = stationIdMapping[oldStationId];
      
        // Parser tous les champs numériques avec gestion de type
        final timestamp = _parseInt(row[1]);
        final kilometrage = _parseDouble(row[2]);
        final jaugeDebut = _parseDouble(row[4]);
        final jaugeFin = _parseDouble(row[5]);
        final nbKwh = _parseDouble(row[6]);
        final paye = _parseDouble(row[8]);
        final prixE10 = _parseDouble(row[9]); 
      
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
        );
        try {

         await _db.insertCharge(charge);

         importCount++;
        } catch (e, stackTrace) {
         print('ERREUR insertCharge ligne ${i + 1}: $e');
         print('StackTrace: $stackTrace');
         print('Charge: horodatage=${charge.horodatage}, km=${charge.kilometrage}, station=${charge.stationId}');
         rethrow; // Pour voir l'erreur complète
        }
        if (importCount % 10 == 0) {
          print('$importCount charges importées...');
        }
      } catch (e) {
        print('Erreur ligne ${i + 1}: $e - Row: $row');
      }
    }
  
    print('Import terminé: $importCount charges importées');
    return importCount;
  }

  /// Importe à la fois les stations et les charges
  Future<Map<String, int>> importAll(String stationsPath, String chargesPath) async {
    // D'abord importer les stations et récupérer le mapping des IDs
    final stationIdMapping = await importStations(stationsPath);
    
    // Ensuite importer les charges avec le mapping
    final chargesCount = await importCharges(chargesPath, stationIdMapping);
    
    return {
      'stations': stationIdMapping.length,
      'charges': chargesCount,
    };
  }

  // Helpers pour parser les valeurs
  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '.');
      return double.parse(cleaned);
    }
    throw FormatException('Cannot parse double from: $value');
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.parse(value);
    }
    throw FormatException('Cannot parse int from: $value');
  }
}
