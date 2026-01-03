import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/charge.dart';
import '../models/station.dart';
import '../models/trajet.dart';
import '../models/parametre.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('carwatt.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Table des paramètres
    await db.execute('''
      CREATE TABLE parametres (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL UNIQUE,
        valeur TEXT,
        valeur_num REAL,
        valeur_date INTEGER
      )
    ''');

    // Table des stations
    await db.execute('''
      CREATE TABLE stations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        adresse TEXT,
        reseaux TEXT
      )
    ''');

    // Table des charges
    await db.execute('''
      CREATE TABLE charges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        horodatage INTEGER NOT NULL,
        kilometrage REAL,
        jauge_debut REAL NOT NULL,
        jauge_fin REAL NOT NULL,
        nb_kwh REAL NOT NULL,
        mode_saisie TEXT CHECK(mode_saisie IN ('montant', 'prixKwh')) NOT NULL,
        paye REAL NOT NULL,
        prix_au_kwh REAL,
        prix_e10 REAL,
        station_id INTEGER,
        statut TEXT CHECK(statut IN ('draft', 'complete')) NOT NULL DEFAULT 'complete',
        prix_pondere REAL,
        distance REAL,
        conso_batterie REAL,
        conso_kwh_au_100 REAL,
        conso_essence REAL,
        economie_totale REAL,
        economie_au_100 REAL,
        charge_pertes_pct REAL,
        FOREIGN KEY (station_id) REFERENCES stations(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_charges_horodatage ON charges(horodatage)
    ''');

    // Table des trajets
    await db.execute('''
      CREATE TABLE trajets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        recharge_depart INTEGER NOT NULL,
        recharge_arrivee INTEGER NOT NULL,
        qt_energie_percent REAL NOT NULL,
        FOREIGN KEY (recharge_depart) REFERENCES charges(id) ON DELETE CASCADE,
        FOREIGN KEY (recharge_arrivee) REFERENCES charges(id) ON DELETE CASCADE
      )
    ''');

    // Insérer les paramètres par défaut
    await _insertDefaultParameters(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration vers version 2 : ajout du champ statut
      await db.execute('''
        ALTER TABLE charges ADD COLUMN statut TEXT CHECK(statut IN ('draft', 'complete')) NOT NULL DEFAULT 'complete'
      ''');
    }
  }

  // ========== NETTOYAGE ==========

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('trajets');
    await db.delete('charges');
    await db.delete('stations');
  }

  Future<void> _insertDefaultParameters(Database db) async {
    final defaultParams = [
      {'nom': 'capacite_batterie', 'valeur_num': 64.0}, // kWh
      {'nom': 'conso_moyenne_essence', 'valeur_num': 6.5}, // L/100km
      {'nom': 'odo_initial', 'valeur_num': 0.0}, // km
      {'nom': 'date_achat', 'valeur_date': DateTime.now().millisecondsSinceEpoch},
    ];

    for (var param in defaultParams) {
      await db.insert('parametres', param);
    }
  }

  // ========== MÉTHODES PARAMÈTRES ==========

  Future<Map<String, dynamic>> getParametres() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('parametres');

    Map<String, dynamic> params = {};
    for (var map in maps) {
      final param = Parametre.fromMap(map);
      if (param.valeurNum != null) {
        params[param.nom] = param.valeurNum;
      } else if (param.valeurDate != null) {
        params[param.nom] = DateTime.fromMillisecondsSinceEpoch(param.valeurDate!);
      } else {
        params[param.nom] = param.valeur;
      }
    }
    return params;
  }

  Future<void> updateParametre(String nom, dynamic valeur) async {
    final db = await database;
    Map<String, dynamic> data = {'nom': nom};

    if (valeur is double || valeur is int) {
      data['valeur_num'] = valeur.toDouble();
    } else if (valeur is DateTime) {
      data['valeur_date'] = valeur.millisecondsSinceEpoch;
    } else {
      data['valeur'] = valeur.toString();
    }

    await db.insert(
      'parametres',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ========== MÉTHODES STATIONS ==========

  Future<int> insertStation(Station station) async {
    final db = await database;
    return await db.insert('stations', station.toMap());
  }

  Future<List<Station>> getStations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('stations');
    return List.generate(maps.length, (i) => Station.fromMap(maps[i]));
  }

  Future<Station?> getStation(int id) async {
    final db = await database;
    final maps = await db.query(
      'stations',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Station.fromMap(maps.first);
  }

  Future<void> updateStation(Station station) async {
    final db = await database;
    await db.update(
      'stations',
      station.toMap(),
      where: 'id = ?',
      whereArgs: [station.id],
    );
  }

  Future<void> deleteStation(int id) async {
    final db = await database;
    await db.delete(
      'stations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== MÉTHODES CHARGES ==========

  Future<Charge?> getPreviousCharge(DateTime horodatage) async {
    final db = await database;
    final maps = await db.query(
      'charges',
      where: 'horodatage < ?',
      whereArgs: [horodatage.millisecondsSinceEpoch],
      orderBy: 'horodatage DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Charge.fromMap(maps.first);
  }

  Future<Charge> calculateFields(Charge charge, Charge? previous) async {
    final params = await getParametres();
    final capaciteBatterie = params['capacite_batterie'] as double;
    final consoMoyenneEssence = params['conso_moyenne_essence'] as double;

    // Prix E10 : snapshot de la valeur précédente ou actuelle
    final prixE10 = charge.prixE10 ?? previous?.prixE10 ?? 1.6;

    // Prix au kWh si mode saisie = montant
    final prixAuKwh = charge.modeSaisie == ModeSaisie.montant
        ? charge.paye / charge.nbKwh
        : charge.prixAuKwh;

    // Distance
    final distance = previous != null && charge.kilometrage != null && previous.kilometrage != null
        ? charge.kilometrage! - previous.kilometrage!
        : 37.0; // Valeur initiale par défaut

    // Consommation batterie (%)
    final consoBatterie = previous != null
        ? previous.jaugeFin - charge.jaugeDebut
        : 0.0;

    // Consommation kWh au 100
    final consoKwhAu100 = distance > 0
        ? (consoBatterie / 100.0) * capaciteBatterie / distance * 100.0
        : 0.0;

    // Consommation essence équivalente
    final consoEssence = distance * prixE10 * consoMoyenneEssence / 100.0;

    // Prix pondéré
    final prixPondere = previous != null
        ? (charge.paye + charge.jaugeDebut * previous.prixPondere!) / charge.jaugeFin
        : charge.paye / charge.jaugeFin;

    // Pertes de charge (%)
    final chargePertesPct = ((charge.jaugeFin - charge.jaugeDebut) / 100.0 * capaciteBatterie / charge.nbKwh) * 100.0;

    return charge.copyWith(
      prixE10: prixE10,
      prixAuKwh: prixAuKwh,
      distance: distance,
      consoBatterie: consoBatterie,
      consoKwhAu100: consoKwhAu100,
      consoEssence: consoEssence,
      prixPondere: prixPondere,
      chargePertesPct: chargePertesPct,
    );
  }

  Future<double> getEconomieCumuleeAvant(DateTime horodatage) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(conso_essence), 0) - COALESCE(SUM(paye), 0) as economie
      FROM charges
      WHERE horodatage < ? AND statut = 'complete'
    ''', [horodatage.millisecondsSinceEpoch]);

    final economie = result.first['economie'];
    if (economie == null) return 0.0;
    if (economie is int) return economie.toDouble();
    if (economie is double) return economie;
    return 0.0;
  }

  Future<void> recalculateFollowingCharges(DateTime fromHorodatage) async {
    final db = await database;

    // Récupérer toutes les charges à partir de cette date
    final chargesMaps = await db.query(
      'charges',
      where: 'horodatage >= ? AND statut = ?',
      whereArgs: [fromHorodatage.millisecondsSinceEpoch, 'complete'],
      orderBy: 'horodatage ASC',
    );

    // Calculer l'économie cumulée avant cette date
    double economieCumulee = await getEconomieCumuleeAvant(fromHorodatage);

    // Calculer la distance totale avant cette date
    final distanceTotaleResult = await db.rawQuery('''
      SELECT COALESCE(SUM(distance), 0) as total
      FROM charges
      WHERE horodatage < ? AND statut = 'complete'
    ''', [fromHorodatage.millisecondsSinceEpoch]);
    
    final distanceTotaleValue = distanceTotaleResult.first['total'];
    double distanceTotale = 0.0;
    if (distanceTotaleValue is int) {
      distanceTotale = distanceTotaleValue.toDouble();
    } else if (distanceTotaleValue is double) {
      distanceTotale = distanceTotaleValue;
    }

    // Recalculer pour chaque charge suivante
    for (var chargeMap in chargesMaps) {
      final charge = Charge.fromMap(chargeMap);
      
      economieCumulee += (charge.consoEssence ?? 0.0) - charge.paye;
      distanceTotale += charge.distance ?? 0.0;
      
      final economieAu100 = distanceTotale > 0 ? economieCumulee / distanceTotale * 100.0 : 0.0;

      await db.update(
        'charges',
        {
          'economie_totale': economieCumulee,
          'economie_au_100': economieAu100,
        },
        where: 'id = ?',
        whereArgs: [charge.id],
      );
    }
  }

  Future<int> insertCharge(Charge charge) async {
    final db = await database;

    // 1. Récupérer la charge précédente
    final previous = await getPreviousCharge(charge.horodatage);

    // 2. Calculer tous les champs
    final calculatedCharge = await calculateFields(charge, previous);

    // 3. Calculer l'économie cumulée
    final economieCumulee = await getEconomieCumuleeAvant(charge.horodatage) +
        (calculatedCharge.consoEssence ?? 0.0) - calculatedCharge.paye;

    // 4. Calculer la distance totale
    final distanceTotaleResult = await db.rawQuery('''
      SELECT COALESCE(SUM(distance), 0) as total
      FROM charges
      WHERE horodatage <= ? AND statut = 'complete'
    ''', [charge.horodatage.millisecondsSinceEpoch]);
    
    final distanceTotaleValue = distanceTotaleResult.first['total'];
    double distanceTotaleBase = 0.0;
    if (distanceTotaleValue is int) {
      distanceTotaleBase = distanceTotaleValue.toDouble();
    } else if (distanceTotaleValue is double) {
      distanceTotaleBase = distanceTotaleValue;
    }
    final distanceTotale = distanceTotaleBase + (calculatedCharge.distance ?? 0.0);

    final economieAu100 = distanceTotale > 0 ? economieCumulee / distanceTotale * 100.0 : 0.0;

    final finalCharge = calculatedCharge.copyWith(
      economieTotale: economieCumulee,
      economieAu100: economieAu100,
    );

    // 5. Insérer la charge
    final id = await db.insert('charges', finalCharge.toMap());

    // 6. Recalculer les charges suivantes (économie cumulée)
    await recalculateFollowingCharges(charge.horodatage);

    return id;
  }

  Future<List<Charge>> getCharges({String? orderBy}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        c.*,
        s.nom as station_nom,
        s.latitude as station_latitude,
        s.longitude as station_longitude
      FROM charges c
      LEFT JOIN stations s ON c.station_id = s.id
      ORDER BY ${orderBy ?? 'horodatage DESC'}
    ''');

    return List.generate(maps.length, (i) => Charge.fromMap(maps[i]));
  }

  Future<Charge?> getCharge(int id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT 
        c.*,
        s.nom as station_nom,
        s.latitude as station_latitude,
        s.longitude as station_longitude
      FROM charges c
      LEFT JOIN stations s ON c.station_id = s.id
      WHERE c.id = ?
    ''', [id]);

    if (maps.isEmpty) return null;
    return Charge.fromMap(maps.first);
  }

  Future<void> updateCharge(Charge charge) async {
    final db = await database;

    // Récupérer la charge précédente
    final previous = await getPreviousCharge(charge.horodatage);

    // Recalculer les champs
    final calculatedCharge = await calculateFields(charge, previous);

    // Recalculer l'économie cumulée pour cette charge
    final economieCumulee = await getEconomieCumuleeAvant(charge.horodatage) +
        (calculatedCharge.consoEssence ?? 0.0) - calculatedCharge.paye;

    final distanceTotaleResult = await db.rawQuery('''
      SELECT COALESCE(SUM(distance), 0) as total
      FROM charges
      WHERE horodatage <= ? AND statut = 'complete'
    ''', [charge.horodatage.millisecondsSinceEpoch]);
    
    final distanceTotaleValue = distanceTotaleResult.first['total'];
    double distanceTotale = 0.0;
    if (distanceTotaleValue is int) {
     distanceTotale = distanceTotaleValue.toDouble();
    } else if (distanceTotaleValue is double) {
     distanceTotale = distanceTotaleValue;
    }
    final economieAu100 = distanceTotale > 0 ? economieCumulee / distanceTotale * 100.0 : 0.0;

    final finalCharge = calculatedCharge.copyWith(
      economieTotale: economieCumulee,
      economieAu100: economieAu100,
    );

    await db.update(
      'charges',
      finalCharge.toMap(),
      where: 'id = ?',
      whereArgs: [charge.id],
    );

    // Recalculer les charges suivantes
    await recalculateFollowingCharges(charge.horodatage);
  }

  Future<void> deleteCharge(int id) async {
    final db = await database;
    
    // Récupérer l'horodatage avant suppression
    final charge = await getCharge(id);
    if (charge == null) return;

    await db.delete(
      'charges',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Recalculer les charges suivantes
    await recalculateFollowingCharges(charge.horodatage);
  }

  // ========== MÉTHODES TRAJETS ==========

  Future<int> insertTrajet(Trajet trajet) async {
    final db = await database;
    return await db.insert('trajets', trajet.toMap());
  }

  Future<List<Trajet>> getTrajets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trajets',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Trajet.fromMap(maps[i]));
  }

  Future<void> deleteTrajet(int id) async {
    final db = await database;
    await db.delete(
      'trajets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== FERMETURE ==========

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
