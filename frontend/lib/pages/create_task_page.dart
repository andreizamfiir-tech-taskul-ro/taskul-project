import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _category = 'Curatenie';
  LatLng _pin = const LatLng(44.4268, 26.1025);

  final MapController _mapController = MapController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _contactNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0040FF);

    Widget sectionCard({required String title, required List<Widget> children}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
    }

    InputDecoration fieldDecoration(String label) {
      return InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E6F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue),
        ),
      );
    }

    final detailsCard = sectionCard(
      title: 'Detalii task',
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: fieldDecoration('Titlu* (min 16 caractere)').copyWith(
            hintText: 'ex: Reparatie instalatie electrica',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: fieldDecoration('Categorie*'),
          items: const [
            DropdownMenuItem(value: 'Curatenie', child: Text('Curatenie')),
            DropdownMenuItem(value: 'Reparatii', child: Text('Reparatii')),
            DropdownMenuItem(value: 'Livrare', child: Text('Livrare')),
            DropdownMenuItem(value: 'IT', child: Text('IT / Software')),
          ],
          onChanged: (val) => setState(() => _category = val ?? _category),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          decoration: fieldDecoration('Buget estimat (RON)').copyWith(
            hintText: 'ex: 350',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          minLines: 4,
          maxLines: 6,
          decoration: fieldDecoration('Descriere*').copyWith(
            hintText: 'Spune ce trebuie facut, materiale, deadline etc.',
          ),
        ),
      ],
    );

    final contactCard = sectionCard(
      title: 'Date de contact',
      children: [
        TextField(
          controller: _contactNameCtrl,
          decoration: fieldDecoration('Persoana de contact*'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          decoration: fieldDecoration('Email*'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: fieldDecoration('Numar de telefon*'),
        ),
      ],
    );

    final locationCard = sectionCard(
      title: 'Locatie',
      children: [
        TextField(
          controller: _cityCtrl,
          decoration: fieldDecoration('Localitate*').copyWith(
            hintText: 'ex: Bucuresti, Sectorul 3',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _addressCtrl,
          decoration: fieldDecoration('Adresa completa').copyWith(
            hintText: 'Strada Exemplu nr. 10, bl. X, ap. 5',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E6F0)),
            color: const Color(0xFFF7F9FC),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pin,
                initialZoom: 13,
                onTap: (tapPosition, latLng) {
                  setState(() {
                    _pin = latLng;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.taskul.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pin,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, color: Color(0xFF0040FF), size: 38),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Apasa pe harta pentru a muta pin-ul. Completeaza manual localitatea/adresa daca vrei.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );

    final actionsRow = Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: primaryBlue),
            ),
            child: Text(
              'Previzualizeaza',
              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Publica task'),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Creeaza un task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Publica un task nou',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Completeaza detaliile, alege categoria si publica. Poti edita oricand ulterior.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                detailsCard,
                const SizedBox(height: 12),
                contactCard,
                const SizedBox(height: 12),
                locationCard,
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: actionsRow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
