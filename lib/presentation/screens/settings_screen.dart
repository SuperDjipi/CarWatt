import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart' as csv_export;
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/charge.dart';
// import 'package:carwatt/data/models/trajet.dart';
import 'package:carwatt/data/utils/csv_importer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  bool _isLoading = true;
  
  // Paramètres
  double _capaciteBatterie = 64.0;
  double _consoMoyenneEssence = 6.5;
  double _odoInitial = 0.0;
  DateTime _dateAchat = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadParametres();
  }

  Future<void> _loadParametres() async {
    setState(() => _isLoading = true);
    
    try {
      final params = await _db.getParametres();
      setState(() {
        _capaciteBatterie = params['capacite_batterie'] ?? 64.0;
        _consoMoyenneEssence = params['conso_moyenne_essence'] ?? 6.5;
        _odoInitial = params['odo_initial'] ?? 0.0;
        _dateAchat = params['date_achat'] ?? DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveParametre(String nom, dynamic valeur) async {
    await _db.updateParametre(nom, valeur);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paramètre enregistré'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _exportDataCSV() async {
    try {
      // Demander où sauvegarder (uniquement sur desktop)
      String? outputPath;
      
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        outputPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Choisir le dossier de sauvegarde',
        );
        
        if (outputPath == null) {
          // L'utilisateur a annulé
          return;
        }
      } else {
        // Sur mobile, utiliser le dossier temporaire
        final tempDir = await getTemporaryDirectory();
        outputPath = tempDir.path;
      }
      
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      // Export des stations
      final stations = await _db.getStations();
      final stationsData = [
        ['Id', 'name', 'latitude', 'longitude', 'address', 'network'],
        ...stations.map((s) => [
          s.id.toString(),
          s.nom,
          s.positionGps?.latitude.toString() ?? '',
          s.positionGps?.longitude.toString() ?? '',
          s.adresse ?? '',
          s.reseaux.join(';'),
        ]),
      ];
      
      final stationsCsv = const csv_export.ListToCsvConverter(
        fieldDelimiter: '\t',
        eol: '\n',
      ).convert(stationsData);
      
      final stationsFile = File('$outputPath/carwatt_stations_$timestamp.csv');
      await stationsFile.writeAsString(stationsCsv, encoding: latin1);
      
      // Export des charges
      final charges = await _db.getCharges(orderBy: 'horodatage ASC');
      final chargesData = [
        [
          'id',
          'timestamp',
          'mileage',
          'stationId',
          'startChargePercentage',
          'endChargePercentage',
          'kwhAmount',
          'inputMode',
          'amountPaid',
          'e10Price',
          'statut',
        ],
        ...charges.map((c) => [
          c.id.toString(),
          c.horodatage.millisecondsSinceEpoch.toString(),
          c.kilometrage?.toStringAsFixed(0) ?? '',
          c.stationId?.toString() ?? '',
          c.jaugeDebut.toStringAsFixed(1),
          c.jaugeFin.toStringAsFixed(1),
          c.nbKwh.toStringAsFixed(2),
          c.modeSaisie == ModeSaisie.montant ? 'BY_AMOUNT' : 'BY_PRICE',
          c.paye.toStringAsFixed(2),
          c.prixE10?.toStringAsFixed(3) ?? '',
          c.statut == StatutCharge.draft ? 'DRAFT' : 'COMPLETE',
        ]),
      ];
      
      final chargesCsv = const csv_export.ListToCsvConverter(
        fieldDelimiter: ',',
        eol: '\n',
      ).convert(chargesData);
      
      final chargesFile = File('$outputPath/carwatt_charges_$timestamp.csv');
      await chargesFile.writeAsString(chargesCsv, encoding: utf8);
      
      if (mounted) {
        if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export réussi dans :\n$outputPath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Sur mobile, partager les fichiers
          await Share.shareXFiles(
            [
              XFile(stationsFile.path),
              XFile(chargesFile.path),
            ],
            subject: 'Export CarWatt',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'export : $e')),
        );
      }
    }
  }

  Future<void> _importCSV() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImportCSVScreen(),
      ),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer toutes les données ?'),
        content: const Text(
          'Cette action est irréversible. Toutes les charges et stations seront supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Toutes les données ont été supprimées'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Section Véhicule
                const Text(
                  'Véhicule',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildEditableCard(
                  icon: Icons.battery_charging_full,
                  title: 'Capacité de la batterie',
                  value: '$_capaciteBatterie kWh',
                  onTap: () => _showEditDialog(
                    title: 'Capacité de la batterie',
                    initialValue: _capaciteBatterie,
                    unit: 'kWh',
                    onSave: (value) {
                      setState(() => _capaciteBatterie = value);
                      _saveParametre('capacite_batterie', value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildEditableCard(
                  icon: Icons.calendar_today,
                  title: 'Date d\'achat',
                  value: DateFormat('dd/MM/yyyy').format(_dateAchat),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateAchat,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _dateAchat = date);
                      _saveParametre('date_achat', date);
                    }
                  },
                ),
                const SizedBox(height: 12),
                
                _buildEditableCard(
                  icon: Icons.speed,
                  title: 'Kilométrage initial',
                  value: '${_odoInitial.toStringAsFixed(0)} km',
                  onTap: () => _showEditDialog(
                    title: 'Kilométrage initial',
                    initialValue: _odoInitial,
                    unit: 'km',
                    onSave: (value) {
                      setState(() => _odoInitial = value);
                      _saveParametre('odo_initial', value);
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Section Carburant
                const Text(
                  'Comparaison essence',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildEditableCard(
                  icon: Icons.show_chart,
                  title: 'Consommation moyenne essence',
                  value: '$_consoMoyenneEssence L/100km',
                  onTap: () => _showEditDialog(
                    title: 'Consommation essence',
                    initialValue: _consoMoyenneEssence,
                    unit: 'L/100km',
                    onSave: (value) {
                      setState(() => _consoMoyenneEssence = value);
                      _saveParametre('conso_moyenne_essence', value);
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Section Import/Export
                const Text(
                  'Données',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildActionCard(
                  icon: Icons.upload_file,
                  title: 'Importer depuis CSV',
                  subtitle: 'Importer des stations et charges',
                  color: Colors.blue,
                  onTap: _importCSV,
                ),
                const SizedBox(height: 12),
                
                _buildActionCard(
                  icon: Icons.download,
                  title: 'Exporter les données (CSV)',
                  subtitle: 'Sauvegarder stations et charges',
                  color: Colors.green,
                  onTap: _exportDataCSV,
                ),
                const SizedBox(height: 12),
                
                _buildActionCard(
                  icon: Icons.delete_forever,
                  title: 'Supprimer toutes les données',
                  subtitle: 'Action irréversible',
                  color: Colors.red,
                  onTap: _showDeleteConfirmation,
                ),
                const SizedBox(height: 32),

                // À propos
                Center(
                  child: Column(
                    children: [
                      Text(
                        'CarWatt v1.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Suivi de recharges électriques',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildEditableCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.grey[700], size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog({
    required String title,
    required double initialValue,
    required String unit,
    int decimals = 1,
    required Function(double) onSave,
  }) {
    final controller = TextEditingController(
      text: initialValue.toStringAsFixed(decimals),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              if (value != null) {
                onSave(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

// Écran d'import CSV réutilisable
class ImportCSVScreen extends StatefulWidget {
  const ImportCSVScreen({super.key});

  @override
  State<ImportCSVScreen> createState() => _ImportCSVScreenState();
}

class _ImportCSVScreenState extends State<ImportCSVScreen> {
  final _importer = CsvImporter();
  bool _isImporting = false;
  String? _stationsPath;
  String? _chargesPath;
  Map<String, int>? _importResult;

  Future<void> _showWarningAndImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Attention'),
          ],
        ),
        content: const Text(
          'L\'import va REMPLACER toutes vos données actuelles.\n\n'
          'Voulez-vous d\'abord exporter vos données actuelles en CSV ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Exporter d\'abord'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, null),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuer sans exporter'),
          ),
        ],
      ),
    );

    if (confirmed == false) {
      // Annuler
      return;
    }

    if (confirmed == true) {
      // Exporter d'abord
      if (mounted) {
        Navigator.pop(context); // Fermer l'écran d'import
        // Déclencher l'export depuis l'écran précédent
        // On pourrait faire mieux mais pour simplifier :
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Utilisez le bouton "Exporter" dans Paramètres, puis relancez l\'import'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Continuer (confirmed == null)
    await _startImport();
  }

  Future<void> _pickStationsFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      setState(() {
        _stationsPath = result.files.single.path;
      });
    }
  }

  Future<void> _pickChargesFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      setState(() {
        _chargesPath = result.files.single.path;
      });
    }
  }

  Future<void> _startImport() async {
    if (_stationsPath == null || _chargesPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner les deux fichiers CSV')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    try {
      // SUPPRIMER TOUTES LES DONNÉES EXISTANTES
      await DatabaseHelper.instance.deleteAllData();
      
      // Importer les nouvelles données
      final result = await _importer.importAll(_stationsPath!, _chargesPath!);
      
      setState(() {
        _importResult = result;
        _isImporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import réussi : ${result['stations']} stations, ${result['charges']} charges',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'import : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import CSV'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.upload_file,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 32),
            const Text(
              'Importer les données depuis CSV',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // AJOUTER CET AVERTISSEMENT
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'L\'import remplacera toutes vos données existantes',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            _buildFileSelector(
              label: 'Fichier des stations',
              path: _stationsPath,
              onTap: _pickStationsFile,
              icon: Icons.location_on,
            ),
            const SizedBox(height: 16),
            
            _buildFileSelector(
              label: 'Fichier des charges',
              path: _chargesPath,
              onTap: _pickChargesFile,
              icon: Icons.battery_charging_full,
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _isImporting ? null : _showWarningAndImport, // MODIFIER ICI
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isImporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'IMPORTER',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            
            if (_importResult != null) ...[
              const SizedBox(height: 32),
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Import terminé',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_importResult!['stations']} stations importées',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                      Text(
                        '${_importResult!['charges']} charges importées',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // FORCER LE RAFRAÎCHISSEMENT DU DASHBOARD
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Retour au tableau de bord'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector({
    required String label,
    required String? path,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    path != null ? _getFileName(path) : 'Aucun fichier sélectionné',
                    style: TextStyle(
                      fontSize: 12,
                      color: path != null ? Colors.green : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.folder_open, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }
}
