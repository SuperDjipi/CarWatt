import 'package:flutter/material.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/charge.dart';
import 'package:carwatt/data/models/station.dart';
import 'package:carwatt/presentation/screens/station_form_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class ChargeFormScreen extends StatefulWidget {
  final Charge? charge; // null = nouvelle charge, sinon édition
  
  const ChargeFormScreen({
    super.key,
    this.charge,
  });

  @override
  State<ChargeFormScreen> createState() => _ChargeFormScreenState();
}

class _ChargeFormScreenState extends State<ChargeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;
  
  // Contrôleurs
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _kilometrageController;
  late TextEditingController _jaugeDebutController;
  late TextEditingController _jaugeFinController;
  late TextEditingController _nbKwhController;
  late TextEditingController _payeController;
  late TextEditingController _prixKwhController;
  late TextEditingController _prixE10Controller;
  
  // État
  bool _isLoading = true;
  bool _isSaving = false;
  DateTime _horodatage = DateTime.now();
  ModeSaisie _modeSaisie = ModeSaisie.montant;
  Station? _selectedStation;
  List<Station> _stations = [];
  LatLng? _userLocation;

  double _jaugeDebut = 20.0;
  double _jaugeFin = 80.0;
  
  bool _isDraft = false;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadData();
  }

  void _initializeControllers() {
    final now = DateTime.now();
    _dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(now),
    );
    _timeController = TextEditingController(
      text: DateFormat('HH:mm').format(now),
    );
    _kilometrageController = TextEditingController();
    _jaugeDebutController = TextEditingController();
    _jaugeFinController = TextEditingController();
    _nbKwhController = TextEditingController();
    _payeController = TextEditingController();
    _prixKwhController = TextEditingController();
    _prixE10Controller = TextEditingController();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Charger les stations
      final stations = await _db.getStations();
      
      // Obtenir la position de l'utilisateur
      LatLng? userLoc;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition();
          userLoc = LatLng(position.latitude, position.longitude);
        }
      } catch (e) {
        // Pas de géolocalisation
      }
      
      if (widget.charge != null) {
        // Mode édition
        _loadExistingCharge();
      } else {
        // Mode création - pré-remplir avec données intelligentes
        await _prefillNewCharge(stations, userLoc);
      }
      
      setState(() {
        _stations = stations;
        _userLocation = userLoc;
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

  void _loadExistingCharge() async {
    final charge = widget.charge!;
    _horodatage = charge.horodatage;
    _dateController.text = DateFormat('dd/MM/yyyy').format(charge.horodatage);
    _timeController.text = DateFormat('HH:mm').format(charge.horodatage);
    _kilometrageController.text = charge.kilometrage?.toStringAsFixed(0) ?? '';

    _jaugeDebut = charge.jaugeDebut;
    _jaugeFin = charge.jaugeFin;
    _jaugeDebutController.text = charge.jaugeDebut.toStringAsFixed(0);
    _jaugeFinController.text = charge.jaugeFin.toStringAsFixed(0);
    _nbKwhController.text = charge.nbKwh.toStringAsFixed(2);
    _payeController.text = charge.paye.toStringAsFixed(2);
    _modeSaisie = charge.modeSaisie;
    if (charge.prixAuKwh != null) {
      _prixKwhController.text = charge.prixAuKwh!.toStringAsFixed(3);
    }
    if (charge.prixE10 != null) {
      _prixE10Controller.text = charge.prixE10!.toStringAsFixed(3);
    } else {
      _prixE10Controller.text = '1.600'; 
    }
    if (charge.stationId != null) {
      final station = await _db.getStation(charge.stationId!);
      setState(() {
        _selectedStation = station;
      });
    }
  }

  Future<void> _prefillNewCharge(List<Station> stations, LatLng? userLoc) async {
    // 1. Récupérer la dernière charge pour pré-remplir
    final charges = await _db.getCharges(orderBy: 'horodatage DESC');
    final derniereCharge = charges.isNotEmpty ? charges.first : null;
    
    // 2. Pré-remplir le kilométrage avec le dernier connu
    if (derniereCharge?.kilometrage != null) {
      _kilometrageController.text = derniereCharge!.kilometrage!.toStringAsFixed(0);
    }
    
    // 3. Pré-remplir la jauge de début avec la jauge de fin de la dernière charge
    // en fait inutile
    
    // 4. Proposer la station la plus proche
    if (userLoc != null && stations.isNotEmpty) {
      Station? closestStation;
      double minDistance = double.infinity;
      
      for (var station in stations) {
        final distance = station.distanceFrom(userLoc);
        if (distance != null && distance < minDistance) {
          minDistance = distance;
          closestStation = station;
        }
      }
      
      if (closestStation != null) {
        _selectedStation = closestStation;
        
        // 5. Pré-remplir le prix au kWh avec le dernier prix de cette station ou réseau
        await _prefillPrixKwh(closestStation, derniereCharge);
      }
    } else if (derniereCharge?.stationId != null) {
      // Pas de géoloc, utiliser la dernière station
      _selectedStation = await _db.getStation(derniereCharge!.stationId!);
      await _prefillPrixKwh(_selectedStation, derniereCharge);
    }
    
    // 6. Pré-remplir le prix E10 avec le dernier connu
    if (derniereCharge?.prixE10 != null) {
      _prixE10Controller.text = derniereCharge!.prixE10!.toStringAsFixed(3);
    } else {
      _prixE10Controller.text = '1.600';
    }
  }

  Future<void> _prefillPrixKwh(Station? station, Charge? derniereCharge) async {
    if (station == null) return;
    
    // Chercher la dernière charge dans cette station ou ce réseau
    final charges = await _db.getCharges();
    
    // D'abord, chercher dans la même station
    final chargesStation = charges.where((c) => c.stationId == station.id).toList();
    if (chargesStation.isNotEmpty) {
      final derniere = chargesStation.last;
      if (derniere.prixAuKwh != null) {
        _prixKwhController.text = derniere.prixAuKwh!.toStringAsFixed(3);
        return;
      }
    }
    
    // Sinon, chercher dans le même réseau
    if (station.reseaux.isNotEmpty) {
      final network = station.reseaux.first;
      final stationsReseau = await _db.getStations();
      final stationIds = stationsReseau
          .where((s) => s.reseaux.contains(network))
          .map((s) => s.id)
          .toList();
      
      final chargesReseau = charges
          .where((c) => c.stationId != null && stationIds.contains(c.stationId))
          .toList();
      
      if (chargesReseau.isNotEmpty) {
        final derniere = chargesReseau.last;
        if (derniere.prixAuKwh != null) {
          _prixKwhController.text = derniere.prixAuKwh!.toStringAsFixed(3);
          return;
        }
      }
    }
    // Sinon, prendre le dernier prix kWh connu, quel que soit le réseau
    if (derniereCharge?.prixAuKwh != null) {
      _prixKwhController.text = derniereCharge!.prixAuKwh!.toStringAsFixed(3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.charge == null ? 'Nouvelle charge' : 'Modifier la charge'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date et heure
                  const Text(
                    'Date et heure',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _timeController,
                          decoration: InputDecoration(
                            labelText: 'Heure',
                            prefixIcon: const Icon(Icons.access_time),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          readOnly: true,
                          onTap: _selectTime,
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Requis' : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Station
                  const Text(
                    'Station',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _selectStation,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.ev_station,
                            color: _selectedStation != null
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedStation?.nom ?? 'Sélectionner une station',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _selectedStation != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (_selectedStation != null &&
                                    _userLocation != null &&
                                    _selectedStation!.positionGps != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_selectedStation!.distanceFrom(_userLocation)?.toStringAsFixed(1)} km',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Kilométrage
                  const Text(
                    'Kilométrage',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _kilometrageController,
                    decoration: InputDecoration(
                      labelText: 'Kilométrage actuel',
                      suffixText: 'km',
                      prefixIcon: const Icon(Icons.speed),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),

                  const SizedBox(height: 24),

                  // Jauge batterie
                  const Text(
                    'Batterie',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Jauge début avec slider
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
                            const Row(
                              children: [
                                Icon(Icons.battery_0_bar, color: Colors.grey, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Début de charge',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${_jaugeDebut.toStringAsFixed(0)} %',
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
                          value: _jaugeDebut,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          activeColor: Colors.green,
                          onChanged: (value) {
                            setState(() {
                              _jaugeDebut = value;
                              _jaugeDebutController.text = value.toStringAsFixed(0);
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Jauge fin avec slider
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.battery_full, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Fin de charge',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${_jaugeFin.toStringAsFixed(0)} %',
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
                          value: _jaugeFin,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          activeColor: Colors.green,
                          onChanged: (value) {
                            setState(() {
                              _jaugeFin = value;
                              _jaugeFinController.text = value.toStringAsFixed(0);
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Mode de saisie
                  const Text(
                    'Coût de la charge',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ModeSaisie>(
                    segments: const [
                      ButtonSegment(
                        value: ModeSaisie.montant,
                        label: Text('Montant total'),
                        icon: Icon(Icons.euro),
                      ),
                      ButtonSegment(
                        value: ModeSaisie.prixKwh,
                        label: Text('Prix au kWh'),
                        icon: Icon(Icons.calculate),
                      ),
                    ],
                    selected: {_modeSaisie},
                    onSelectionChanged: (Set<ModeSaisie> newSelection) {
                      setState(() {
                        _modeSaisie = newSelection.first;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Énergie
                  TextFormField(
                    controller: _nbKwhController,
                    decoration: InputDecoration(
                      labelText: 'Énergie',
                      suffixText: 'kWh',
                      prefixIcon: const Icon(Icons.bolt),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Requis';
                      final val = double.tryParse(value!.replaceAll(',', '.'));
                      if (val == null || val <= 0) return 'Valeur invalide';
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  if (_modeSaisie == ModeSaisie.montant) ...[
                    TextFormField(
                      controller: _payeController,
                      decoration: InputDecoration(
                        labelText: 'Montant payé',
                        suffixText: '€',
                        prefixIcon: const Icon(Icons.euro),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Requis';
                        final val = double.tryParse(value!.replaceAll(',', '.'));
                        if (val == null || val < 0) return 'Valeur invalide';
                        return null;
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _prixKwhController,
                            decoration: InputDecoration(
                              labelText: 'Prix au kWh',
                              suffixText: '€/kWh',
                              prefixIcon: const Icon(Icons.euro),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value?.isEmpty ?? true) return 'Requis';
                              final val = double.tryParse(value!.replaceAll(',', '.'));
                              if (val == null || val <= 0) return 'Invalide';
                              return null;
                            },
                            onChanged: (value) => _calculateMontant(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _payeController,
                            decoration: InputDecoration(
                              labelText: 'Montant',
                              suffixText: '€',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            readOnly: true,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Prix E10 (pour référence et calcul des économies)
                  const Text(
                    'Prix essence de référence',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Utilisé pour calculer les économies vs essence',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _prixE10Controller,
                    decoration: InputDecoration(
                      labelText: 'Prix E10',
                      suffixText: '€/L',
                      prefixIcon: const Icon(Icons.local_gas_station),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),

                  const SizedBox(height: 32),

                  // Boutons enregistrer
                  if (widget.charge?.isDraft ?? false) ...[
                    // Si c'est un brouillon, proposer de finaliser
                    ElevatedButton(
                      onPressed: _isSaving ? null : () => _saveCharge(asDraft: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'FINALISER LA CHARGE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isSaving ? null : () => _saveCharge(asDraft: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ENREGISTRER LE BROUILLON'),
                    ),
                  ] else if (widget.charge == null) ...[
                    // Nouvelle charge : proposer brouillon ou complet
                    ElevatedButton(
                      onPressed: _isSaving ? null : () => _saveCharge(asDraft: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'ENREGISTRER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : () => _saveCharge(asDraft: true),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('ENREGISTRER COMME BROUILLON'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ] else ...[
                    // Modification d'une charge complète
                    ElevatedButton(
                      onPressed: _isSaving ? null : () => _saveCharge(asDraft: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'MODIFIER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  if (widget.charge != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _deleteCharge,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('SUPPRIMER'),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  void _calculateMontant() {
    final nbKwh = double.tryParse(_nbKwhController.text.replaceAll(',', '.'));
    final prixKwh = double.tryParse(_prixKwhController.text.replaceAll(',', '.'));
    
    if (nbKwh != null && prixKwh != null) {
      _payeController.text = (nbKwh * prixKwh).toStringAsFixed(2);
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _horodatage,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _horodatage = DateTime(
          date.year,
          date.month,
          date.day,
          _horodatage.hour,
          _horodatage.minute,
        );
        _dateController.text = DateFormat('dd/MM/yyyy').format(_horodatage);
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_horodatage),
    );
    
    if (time != null) {
      setState(() {
        _horodatage = DateTime(
          _horodatage.year,
          _horodatage.month,
          _horodatage.day,
          time.hour,
          time.minute,
        );
        _timeController.text = DateFormat('HH:mm').format(_horodatage);
      });
    }
  }

  Future<void> _selectStation() async {
    final station = await showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          // Trier les stations par distance
          final sortedStations = _userLocation != null
              ? (_stations.toList()..sort((a, b) {
                  final distA = a.distanceFrom(_userLocation) ?? double.infinity;
                  final distB = b.distanceFrom(_userLocation) ?? double.infinity;
                  return distA.compareTo(distB);
                }))
              : _stations;

          return Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Sélectionner une station',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedStations.length + 1,
                  itemBuilder: (context, index) {
                    if (index == sortedStations.length) {
                      // Bouton "Nouvelle station"
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _createNewStation();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Créer une nouvelle station'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      );
                    }

                    final station = sortedStations[index];
                    final distance = _userLocation != null
                        ? station.distanceFrom(_userLocation)
                        : null;

                    return ListTile(
                      leading: const Icon(Icons.ev_station, color: Colors.green),
                      title: Text(station.nom),
                      subtitle: distance != null
                          ? Text('${distance.toStringAsFixed(1)} km')
                          : null,
                      trailing: station.reseaux.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                station.reseaux.first,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                ),
                              ),
                            )
                          : null,
                      onTap: () => Navigator.pop(context, station),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );

    if (station != null) {
      setState(() {
        _selectedStation = station;
      });
      // Pré-remplir le prix kWh en fonction de la nouvelle station
      await _prefillPrixKwh(station, null);
    }
  }

  Future<void> _createNewStation() async {
    final station = await Navigator.push<Station>(
      context,
      MaterialPageRoute(
        builder: (context) => const StationFormScreen(),
      ),
    );

    if (station != null) {
      // Recharger les stations
      final stations = await _db.getStations();
      setState(() {
        _stations = stations;
        _selectedStation = station;
      });
      
      // Pré-remplir le prix kWh pour cette nouvelle station
      await _prefillPrixKwh(station, null);
    }
  }

  Future<void> _saveCharge({required bool asDraft}) async {
    // Pour les brouillons, validation plus souple
    if (!asDraft && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Déterminer le statut
      final statut = asDraft ? StatutCharge.draft : StatutCharge.complete;
      
      // Pour un brouillon, certains champs peuvent être à 0 ou vides
      final charge = Charge(
        id: widget.charge?.id,
        horodatage: _horodatage,
        kilometrage: double.tryParse(_kilometrageController.text.replaceAll(',', '.')),
        jaugeDebut: _jaugeDebut,
        jaugeFin: _jaugeFin,
        nbKwh: asDraft && _nbKwhController.text.isEmpty 
            ? 0.0 
            : double.parse(_nbKwhController.text.replaceAll(',', '.')),
        modeSaisie: _modeSaisie,
        paye: asDraft && _payeController.text.isEmpty 
            ? 0.0 
            : double.parse(_payeController.text.replaceAll(',', '.')),
        prixAuKwh: _modeSaisie == ModeSaisie.prixKwh && _prixKwhController.text.isNotEmpty
            ? double.parse(_prixKwhController.text.replaceAll(',', '.'))
            : null,
        stationId: _selectedStation?.id,
        prixE10: _prixE10Controller.text.isNotEmpty 
            ? double.tryParse(_prixE10Controller.text.replaceAll(',', '.'))
            : null,
        statut: statut, // AJOUTER LE STATUT
      );
      print('Sauvegarde charge - Station ID: ${charge.stationId}');
      if (widget.charge == null) {
        await _db.insertCharge(charge);
      } else {
        await _db.updateCharge(charge);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(asDraft 
                ? 'Brouillon enregistré' 
                : 'Charge enregistrée'),
            backgroundColor: asDraft ? Colors.orange : Colors.green,
          ),
        );
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

  Future<void> _deleteCharge() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette charge ?'),
        content: const Text('Cette action est irréversible.'),
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

    if (confirmed == true && widget.charge != null) {
      try {
        await _db.deleteCharge(widget.charge!.id!);
        if (mounted) {
          Navigator.pop(context, true);
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
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _kilometrageController.dispose();
    _jaugeDebutController.dispose();
    _jaugeFinController.dispose();
    _nbKwhController.dispose();
    _payeController.dispose();
    _prixKwhController.dispose();
    _prixE10Controller.dispose();
    super.dispose();
  }
}
