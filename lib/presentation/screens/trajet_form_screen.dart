import 'package:flutter/material.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/trajet.dart';
import 'package:intl/intl.dart';

class TrajetFormScreen extends StatefulWidget {
  final Trajet? trajet; // null = nouveau trajet
  
  const TrajetFormScreen({
    super.key,
    this.trajet,
  });

  @override
  State<TrajetFormScreen> createState() => _TrajetFormScreenState();
}

class _TrajetFormScreenState extends State<TrajetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;
  
  // Contrôleurs
  late TextEditingController _dateController;
  late TextEditingController _lieuDepartController;
  late TextEditingController _lieuArriveeController;
  late TextEditingController _kmDepartController;
  late TextEditingController _kmArriveeController;
  
  // État
  bool _isSaving = false;
  DateTime _date = DateTime.now();
  double _jaugeDepart = 80.0;
  double _jaugeArrivee = 20.0;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (widget.trajet != null) {
      // Mode édition
      final trajet = widget.trajet!;
      _date = trajet.date;
      _dateController = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(trajet.date),
      );
      _lieuDepartController = TextEditingController(text: trajet.lieuDepart ?? '');
      _lieuArriveeController = TextEditingController(text: trajet.lieuArrivee ?? '');
      _kmDepartController = TextEditingController(
        text: trajet.kilometrageDepart?.toStringAsFixed(0) ?? '',
      );
      _kmArriveeController = TextEditingController(
        text: trajet.kilometrageArrivee?.toStringAsFixed(0) ?? '',
      );
      _jaugeDepart = trajet.jaugeDepartPercent ?? 80.0;
      _jaugeArrivee = trajet.jaugeArriveePercent ?? 20.0;
    } else {
      // Mode création
      _dateController = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
      );
      _lieuDepartController = TextEditingController();
      _lieuArriveeController = TextEditingController();
      _kmDepartController = TextEditingController();
      _kmArriveeController = TextEditingController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trajet == null ? 'Nouveau trajet' : 'Modifier le trajet'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date
            const Text(
              'Date du trajet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Date',
                prefixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              readOnly: true,
              onTap: _selectDate,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Requis' : null,
            ),

            const SizedBox(height: 24),

            // Départ
            const Text(
              'Départ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lieuDepartController,
              decoration: InputDecoration(
                labelText: 'Lieu de départ',
                hintText: 'Ex: Domicile, Bureau, Marseille...',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kmDepartController,
              decoration: InputDecoration(
                labelText: 'Kilométrage départ',
                suffixText: 'km',
                prefixIcon: const Icon(Icons.speed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            
            // Jauge départ avec slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Niveau batterie au départ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_jaugeDepart.toStringAsFixed(0)} %',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _jaugeDepart,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _jaugeDepart = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Arrivée
            const Text(
              'Arrivée',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lieuArriveeController,
              decoration: InputDecoration(
                labelText: 'Lieu d\'arrivée',
                hintText: 'Ex: Travail, Lyon, Supermarché...',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kmArriveeController,
              decoration: InputDecoration(
                labelText: 'Kilométrage arrivée',
                suffixText: 'km',
                prefixIcon: const Icon(Icons.speed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Requis';
                final kmDep = double.tryParse(_kmDepartController.text.replaceAll(',', '.'));
                final kmArr = double.tryParse(value!.replaceAll(',', '.'));
                if (kmDep != null && kmArr != null && kmArr <= kmDep) {
                  return 'Doit être > km départ';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            
            // Jauge arrivée avec slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Niveau batterie à l\'arrivée',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_jaugeArrivee.toStringAsFixed(0)} %',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _jaugeArrivee,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      setState(() {
                        _jaugeArrivee = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Résumé
            if (_kmDepartController.text.isNotEmpty && _kmArriveeController.text.isNotEmpty)
              _buildSummaryCard(),

            const SizedBox(height: 32),

            // Bouton enregistrer
            ElevatedButton(
              onPressed: _isSaving ? null : _saveTrajet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                widget.trajet == null ? 'ENREGISTRER LE TRAJET' : 'MODIFIER',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final kmDep = double.tryParse(_kmDepartController.text.replaceAll(',', '.'));
    final kmArr = double.tryParse(_kmArriveeController.text.replaceAll(',', '.'));
    
    if (kmDep == null || kmArr == null || kmArr <= kmDep) {
      return const SizedBox.shrink();
    }

    final distance = kmArr - kmDep;
    final energieConsommee = _jaugeDepart - _jaugeArrivee;
    
    // Capacité batterie par défaut
    const capaciteBatterie = 64.0;
    final energieKwh = energieConsommee / 100 * capaciteBatterie;
    final consoAu100 = energieKwh / distance * 100;

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calculate, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Résumé du trajet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryRow('Distance', '${distance.toStringAsFixed(0)} km'),
            _buildSummaryRow('Énergie consommée', '${energieConsommee.toStringAsFixed(0)} %'),
            _buildSummaryRow('Énergie (kWh)', '${energieKwh.toStringAsFixed(1)} kWh'),
            _buildSummaryRow('Consommation', '${consoAu100.toStringAsFixed(1)} kWh/100km'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _date = date;
        _dateController.text = DateFormat('dd/MM/yyyy').format(date);
      });
    }
  }

  Future<void> _saveTrajet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final kmDep = double.parse(_kmDepartController.text.replaceAll(',', '.'));
      final kmArr = double.parse(_kmArriveeController.text.replaceAll(',', '.'));
      final energieConsommee = _jaugeDepart - _jaugeArrivee;

      final trajet = Trajet(
        id: widget.trajet?.id,
        date: _date,
        rechargeDepart: null,
        rechargeArrivee: null,
        qtEnergiePercent: energieConsommee,
        type: TypeTrajet.manual,
        lieuDepart: _lieuDepartController.text.trim(),
        lieuArrivee: _lieuArriveeController.text.trim(),
        jaugeDepartPercent: _jaugeDepart,
        jaugeArriveePercent: _jaugeArrivee,
        kilometrageDepart: kmDep,
        kilometrageArrivee: kmArr,
      );

      if (widget.trajet == null) {
        await _db.insertTrajet(trajet);
      } else {
        await _db.updateTrajet(trajet);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _lieuDepartController.dispose();
    _lieuArriveeController.dispose();
    _kmDepartController.dispose();
    _kmArriveeController.dispose();
    super.dispose();
  }
}
