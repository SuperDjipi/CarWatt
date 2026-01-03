import 'package:flutter/material.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/charge.dart';
import 'package:carwatt/data/models/station.dart';
import 'package:carwatt/presentation/screens/import_screen.dart';
import 'package:latlong2/latlong.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _db = DatabaseHelper.instance;
  List<Charge> _charges = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCharges();
  }

  Future<void> _loadCharges() async {
    setState(() => _isLoading = true);
    try {
      final charges = await _db.getCharges();
      setState(() {
        _charges = charges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _addTestData() async {
    setState(() => _isLoading = true);
    try {
      // Créer une station de test
      final stationId = await _db.insertStation(
        Station(
          nom: 'Ionity Aix-en-Provence',
          positionGps: const LatLng(43.5297, 5.4474),
          adresse: 'Aire de la Pioline, A8',
          reseaux: ['Ionity'],
        ),
      );

      // Créer une charge de test
      final charge = Charge(
        horodatage: DateTime.now(),
        kilometrage: 15000,
        jaugeDebut: 20,
        jaugeFin: 80,
        nbKwh: 42.5,
        modeSaisie: ModeSaisie.montant,
        paye: 19.50,
        stationId: stationId,
      );

      await _db.insertCharge(charge);
      await _loadCharges();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Charge de test ajoutée !')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Database CarWatt'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import CSV',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImportScreen(),
                ),
              ).then((_) => _loadCharges());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _charges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.battery_charging_full, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Aucune charge enregistrée'),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addTestData,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une charge de test'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _charges.length,
                  itemBuilder: (context, index) {
                    final charge = _charges[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDate(charge.horodatage),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${charge.paye.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            if (charge.stationNom != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                charge.stationNom!,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                            const Divider(height: 24),
                            _buildInfoRow('Jauge', '${charge.jaugeDebut.toStringAsFixed(0)}% → ${charge.jaugeFin.toStringAsFixed(0)}%'),
                            _buildInfoRow('Énergie', '${charge.nbKwh.toStringAsFixed(1)} kWh'),
                            if (charge.kilometrage != null)
                              _buildInfoRow('Kilométrage', '${charge.kilometrage!.toStringAsFixed(0)} km'),
                            if (charge.distance != null)
                              _buildInfoRow('Distance', '${charge.distance!.toStringAsFixed(0)} km'),
                            if (charge.consoKwhAu100 != null)
                              _buildInfoRow('Consommation', '${charge.consoKwhAu100!.toStringAsFixed(1)} kWh/100km'),
                            if (charge.economieTotale != null)
                              _buildInfoRow('Économie totale', '${charge.economieTotale!.toStringAsFixed(2)} €', Colors.green),
                            if (charge.economieAu100 != null)
                              _buildInfoRow('Économie au 100', '${charge.economieAu100!.toStringAsFixed(2)} €/100km', Colors.green),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _charges.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addTestData,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
