//Gestor de Incidencias IES - Flutter + Supabase Realtime
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // 2. Inicializar Supabase (solo URL y Key)
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    anonKey: dotenv.get('SUPABASE_KEY'),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de Incidencias IES',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ─────────────────────────────────────────────
//  PANTALLA PRINCIPAL – Visor de incidencias
// ─────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  bool _isConfigured = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _incidencias = [];

  @override
  void initState() {
    super.initState();
    _autologin();
  }

  // --- AUTENTICACIÓN AUTOMÁTICA ---
  Future<void> _autologin() async {
    try {
      await _supabase.auth.signInWithPassword(
        email: dotenv.get('CORREO_SUPABASE'),
        password: dotenv.get('CLAVE_SUPABASE'),
      );
      setState(() => _isConfigured = true);
      debugPrint("✅ Sesión iniciada automáticamente");
      await _cargarIncidencias();
    } catch (e) {
      debugPrint("❌ Error en autologin: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- CARGAR INCIDENCIAS ---
  Future<void> _cargarIncidencias() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('incidencias')
          .select()
          .order('fecha', ascending: false);
      setState(() {
        _incidencias = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error cargando incidencias: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- ABRIR FORMULARIO DE NUEVA INCIDENCIA ---
  Future<void> _abrirNuevaIncidencia() async {
    final enviada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReporteroPage()),
    );
    if (enviada == true) {
      await _cargarIncidencias(); // Refresca la lista al volver
    }
  }

  // --- COLOR SEGÚN ESTADO (opcional, por si tu tabla tiene campo estado) ---
  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'resuelta':
        return Colors.green;
      case 'en_proceso':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Incidencias IES"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Actualizar",
            onPressed: _isConfigured ? _cargarIncidencias : null,
          ),
        ],
      ),
      body: !_isConfigured
          ? const Center(child: CircularProgressIndicator())
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _incidencias.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            "No hay incidencias registradas",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarIncidencias,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _incidencias.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final inc = _incidencias[index];
                          final fecha = inc['fecha'] != null
                              ? DateTime.tryParse(inc['fecha'].toString())
                              : null;
                          final fechaStr = fecha != null
                              ? "${fecha.day.toString().padLeft(2, '0')}/"
                                  "${fecha.month.toString().padLeft(2, '0')}/"
                                  "${fecha.year}  "
                                  "${fecha.hour.toString().padLeft(2, '0')}:"
                                  "${fecha.minute.toString().padLeft(2, '0')}"
                              : "Sin fecha";

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Aula + dispositivo
                                  Row(
                                    children: [
                                      const Icon(Icons.room, size: 16,
                                          color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "${inc['aula'] ?? '-'}  ·  ${inc['dispositivo'] ?? '-'}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      // Badge estado (si existe el campo)
                                      if (inc['estado'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _colorEstado(
                                                inc['estado'].toString()),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            inc['estado'].toString(),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Descripción
                                  Text(
                                    inc['descripcion'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  // Miniatura foto (si hay)
                                  if (inc['url_foto'] != null &&
                                      inc['url_foto'].toString().isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        inc['url_foto'].toString(),
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  // Fecha
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time,
                                          size: 13, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        fechaStr,
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      // Botón flotante para nueva incidencia
      floatingActionButton: _isConfigured
          ? FloatingActionButton.extended(
              onPressed: _abrirNuevaIncidencia,
              icon: const Icon(Icons.add),
              label: const Text("Nueva incidencia"),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────
//  PANTALLA DE NUEVO REPORTE (sin cambios)
// ─────────────────────────────────────────────
class ReporteroPage extends StatefulWidget {
  const ReporteroPage({super.key});

  @override
  State<ReporteroPage> createState() => _ReporteroPageState();
}

class _ReporteroPageState extends State<ReporteroPage> {
  final _supabase = Supabase.instance.client;
  final _descController = TextEditingController();

  // Datos del Instituto
  late Map<String, List<String>> _datosInstituto;
  String? _selectedAula;
  String? _selectedDispositivo;
  File? _imageFile;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _datosInstituto = _generarDatosInstituto();
  }

  // --- LÓGICA DE DATOS ---
  Map<String, List<String>> _generarDatosInstituto() {
    final List<String> estandar = [
      "1ºESOA", "1ºESOB", "1ºESOC", "2ºESOA", "2ºESOB", "2ºESOC", "2ºESOD",
      "3ºESOA", "3ºESOB", "3ºESOC", "3ºESOD", "4ºESOA", "4ºESOB", "4ºESOC", "4ºESOD",
      "1ºBACA", "1ºBACB", "2ºBACA", "2ºBACB", "Biblioteca", "Aula Música", "Aula Plástica",
      "Aula Bioloxía 1", "Aula Física e Química"
    ];
    final List<String> especiales = [
      "Aula Informática 1", "Aula Informática 2", "Taller Tecnoloxía",
      "Polos", "Carro 1", "Carro 2"
    ];

    Map<String, List<String>> mapa = {};
    for (var aula in estandar) {
      mapa[aula] = ["Portátil", "Pantalla", "Otro"];
    }
    List<String> pcs = List.generate(24, (i) => "PC ${i + 1}")..add("Otro");
    for (var aula in especiales) {
      mapa[aula] = List.from(pcs);
    }
    return mapa;
  }

  // --- CÁMARA ---
  Future<void> _hacerFoto() async {
    final picker = ImagePicker();
    final foto =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (foto != null) {
      setState(() => _imageFile = File(foto.path));
    }
  }

  // --- ENVÍO A SUPABASE ---
  Future<void> _enviarIncidencia() async {
    if (_selectedAula == null ||
        _selectedDispositivo == null ||
        _descController.text.isEmpty) {
      _mostrarMensaje("Por favor, completa todos los campos");
      return;
    }

    setState(() => _isSending = true);

    try {
      String? imageUrl;

      // 1. Subir imagen si existe
      if (_imageFile != null) {
        final nombreArchivo =
            'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage
            .from('evidencias')
            .upload(nombreArchivo, _imageFile!);
        imageUrl = _supabase.storage
            .from('evidencias')
            .getPublicUrl(nombreArchivo);
      }

      // 2. Insertar fila
      await _supabase.from('incidencias').insert({
        'aula': _selectedAula,
        'dispositivo': _selectedDispositivo,
        'descripcion': _descController.text,
        'url_foto': imageUrl,
        'fecha': DateTime.now().toIso8601String(),
      });

      _mostrarMensaje("✅ Incidencia enviada con éxito");
      _limpiarFormulario();

      // Volver a la pantalla principal indicando que se envió algo
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _mostrarMensaje("❌ Error al enviar: $e");
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _limpiarFormulario() {
    _descController.clear();
    setState(() {
      _selectedAula = null;
      _selectedDispositivo = null;
      _imageFile = null;
    });
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nueva Incidencia"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            // Selector de Aula
            DropdownButtonFormField<String>(
              value: _selectedAula,
              hint: const Text("Selecciona Aula"),
              decoration:
                  const InputDecoration(border: OutlineInputBorder()),
              items: _datosInstituto.keys
                  .map((a) =>
                      DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (val) => setState(() {
                _selectedAula = val;
                _selectedDispositivo = null;
              }),
            ),
            const SizedBox(height: 20),

            // Selector de Dispositivo (dependiente)
            DropdownButtonFormField<String>(
              value: _selectedDispositivo,
              hint: const Text("Selecciona Dispositivo"),
              decoration:
                  const InputDecoration(border: OutlineInputBorder()),
              items: (_selectedAula == null)
                  ? []
                  : _datosInstituto[_selectedAula]!
                      .map((d) =>
                          DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
              onChanged: _selectedAula == null
                  ? null
                  : (val) =>
                      setState(() => _selectedDispositivo = val),
            ),
            const SizedBox(height: 20),

            // Descripción
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Describe el problema...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Botón Cámara
            ElevatedButton.icon(
              onPressed: _hacerFoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text("HACER FOTO"),
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 10),
              Image.file(_imageFile!, height: 150, fit: BoxFit.cover),
            ],

            const SizedBox(height: 40),

            // Botón Enviar
            SizedBox(
              height: 50,
              child: _isSending
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _enviarIncidencia,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        "ENVIAR INCIDENCIA",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}