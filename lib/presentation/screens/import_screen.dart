import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:carwatt/data/utils/csv_importer.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _importer = CsvImporter();
  bool _isImporting = false;
  String? _stationsPath;
  String? _chargesPath;
  Map<String, int>? _importResult;

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
        backgroundColor: Colors.green,
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
            const SizedBox(height: 48),
            
            // Stations file
            _buildFileSelector(
              label: 'Fichier des stations',
              path: _stationsPath,
              onTap: _pickStationsFile,
              icon: Icons.location_on,
            ),
            const SizedBox(height: 16),
            
            // Charges file
            _buildFileSelector(
              label: 'Fichier des charges',
              path: _chargesPath,
              onTap: _pickChargesFile,
              icon: Icons.battery_charging_full,
            ),
            const SizedBox(height: 32),
            
            // Import button
            ElevatedButton(
              onPressed: _isImporting ? null : _startImport,
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
            
            // Result
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
