//Gestor de Incidencias IES - Flutter + Supabase Realtime
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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
      title: 'Gestor de Incidencias IES. Gestor Cliente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

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

  Future<void> _autologin() async {
    try {
      await _supabase.auth.signInWithPassword(
        email: dotenv.get('CORREO_SUPABASE') ?? '',
        password: dotenv.get('CLAVE_SUPABASE') ?? '',
      );
      setState(() => _isConfigured = true);
      await _cargarIncidencias();
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error de login: $e");
    }
  }

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
      setState(() => _isLoading = false);
      debugPrint("Error cargando incidencias: $e");
    }
  }

  // --- NUEVA FUNCIÓN: FORMATO DE FECHA ---
  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) return "Fecha desconocida";
    try {
      final fecha = DateTime.parse(fechaIso).toLocal();
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      final hora = fecha.hour.toString().padLeft(2, '0');
      final min = fecha.minute.toString().padLeft(2, '0');
      return "$dia/$mes/${fecha.year}  $hora:$min";
    } catch (e) {
      return fechaIso; // Fallback al texto crudo si falla el parseo
    }
  }

  // --- NUEVA FUNCIÓN: ELIMINAR INCIDENCIA ---
  void _confirmarEliminacion(Map<String, dynamic> inc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar incidencia"),
        content: const Text("¿Estás seguro de que quieres eliminar esta incidencia de forma permanente?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancelar")
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Cierra el diálogo
              setState(() => _isLoading = true);
              try {
                // Se asume que tu tabla tiene una columna Primary Key llamada 'id'
                await _supabase.from('incidencias').delete().eq('id', inc['id']);
                await _cargarIncidencias();
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Error al eliminar la incidencia")),
                  );
                }
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _getIconoEstado(dynamic estado) {
    switch (estado.toString().toLowerCase()) {
      case '0': case 'resuelta':
        return const Icon(Icons.check_circle, color: Colors.green);
      case '1': case 'en curso': case 'en_proceso':
        return const Icon(Icons.build, color: Colors.blue);
      case '2': case 'pendiente':
        return const Icon(Icons.pending_actions, color: Colors.orange);
      case '3': case 'crítica':
        return const Icon(Icons.report_problem, color: Colors.red);
      default:
        return const Icon(Icons.fiber_new, color: Colors.grey);
    }
  }

  void _verDetallesCompletos(Map<String, dynamic> inc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Detalles de la incidencia"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FECHA EN LOS DETALLES
              Text("Registrada el: ${_formatearFecha(inc['fecha'])}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),

              const Text("MI REPORTE:", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
              const SizedBox(height: 4),
              Text(inc['descripcion'] ?? "Sin descripción proporcionada."),
              
              // VISUALIZACIÓN DE LA IMAGEN SI EXISTE
              if (inc['url_foto'] != null && inc['url_foto'].toString().isNotEmpty) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                const Text("EVIDENCIA FOTOGRÁFICA:", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    inc['url_foto'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      const Text("No se pudo cargar la imagen.", style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              
              const Text("RESPUESTA DEL TÉCNICO:", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
              const SizedBox(height: 8),
              Text(
                inc['observaciones'] != null && inc['observaciones'].toString().isNotEmpty
                ? inc['observaciones'] 
                : "El técnico aún no ha añadido comentarios.",
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cerrar")
          )
        ],
      ),
    );
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
            onPressed: _isConfigured ? _cargarIncidencias : null,
          ),
        ],
      ),
      body: !_isConfigured || _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _incidencias.isEmpty
              ? const Center(child: Text("No hay incidencias registradas"))
              : RefreshIndicator(
                  onRefresh: _cargarIncidencias,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _incidencias.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final inc = _incidencias[index];
                      return Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _verDetallesCompletos(inc), 
                          onLongPress: () => _confirmarEliminacion(inc), // Click largo para eliminar
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          _getIconoEstado(inc['estado']),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "${inc['aula']}  ·  ${inc['dispositivo']}",
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // INDICADOR DE FECHA Y CLIP DE FOTO
                                    Row(
                                      children: [
                                        if (inc['url_foto'] != null)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6),
                                            child: Icon(Icons.attach_file, size: 16, color: Colors.grey),
                                          ),
                                        Text(
                                          _formatearFecha(inc['fecha']),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  inc['descripcion'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _isConfigured
          ? FloatingActionButton.extended(
              onPressed: () async {
                final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReporteroPage()));
                if (r == true) _cargarIncidencias();
              },
              icon: const Icon(Icons.add),
              label: const Text("Nueva incidencia"),
            )
          : null,
    );
  }
}

class ReporteroPage extends StatefulWidget {
  const ReporteroPage({super.key});
  @override
  State<ReporteroPage> createState() => _ReporteroPageState();
}

class _ReporteroPageState extends State<ReporteroPage> {
  final _supabase = Supabase.instance.client;
  final _descController = TextEditingController();
  String? _selectedAula;
  String? _selectedDispositivo;
  File? _imageFile;
  bool _isSending = false;

  Map<String, List<String>> _generarDatosInstituto() {
    final List<String> estandar = [
      "1ºESO A", "1ºESO B", "1ºESO C", "2ºESO A", "2ºESO B", "2ºESO C", "2ºESO D","2ºESO E",
      "3ºESO A", "3ºESO B", "3ºESO C", "3ºESO D", "4ºESO A", "4ºESO B", "4ºESO C", "4ºESO D",
      "1ºBAC A", "1ºBAC B", "2ºBAC A", "2ºBAC B", "Biblioteca", "Aula Música", "Aula Plástica",
      "Aula Bioloxía", "Aula Física ", "Aula Química", "Otro"
    ];
    final List<String> especiales = [
      "Aula Informática 1", "Aula Informática 2", "Taller Tecnoloxía", "Polos", "Carro A", "Carro B"
    ];
    Map<String, List<String>> mapa = {};
    for (var aula in estandar) {
      mapa[aula] = ["Portátil", "Pantalla", "Otro"];
    }
    List<String> pcs = List.generate(30, (i) => "PC ${i + 1}")..add("Otro");
    for (var aula in especiales) {
      mapa[aula] = List.from(pcs);
    }
    return mapa;
  }

  @override
  Widget build(BuildContext context) {
    final datos = _generarDatosInstituto();
    return Scaffold(
      appBar: AppBar(title: const Text("Nueva Incidencia")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedAula,
              hint: const Text("Selecciona Aula"),
              items: datos.keys.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (val) => setState(() { _selectedAula = val; _selectedDispositivo = null; }),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedDispositivo,
              hint: const Text("Selecciona Dispositivo"),
              items: (_selectedAula == null) ? [] : datos[_selectedAula]!.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => _selectedDispositivo = val),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descController, 
              decoration: const InputDecoration(hintText: "Descripción del problema..."),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            
            // PREVISUALIZACIÓN DE IMAGEN ANTES DE SUBIR
            if (_imageFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_imageFile!, height: 150, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
            ],
            
            ElevatedButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                if (foto != null) setState(() => _imageFile = File(foto.path));
              },
              icon: Icon(_imageFile == null ? Icons.camera_alt : Icons.cameraswitch),
              label: Text(_imageFile == null ? "HACER FOTO" : "CAMBIAR FOTO"),
            ),
            const SizedBox(height: 40),
            
            _isSending 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: _enviarIncidencia,
                  child: const Text("ENVIAR INCIDENCIA", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarIncidencia() async {
    if (_selectedAula == null || _selectedDispositivo == null || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, rellena todos los campos de texto.")),
      );
      return;
    }
    setState(() => _isSending = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        final name = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('evidencias').upload(name, _imageFile!);
        imageUrl = _supabase.storage.from('evidencias').getPublicUrl(name);
      }
      await _supabase.from('incidencias').insert({
        'aula': _selectedAula,
        'dispositivo': _selectedDispositivo,
        'descripcion': _descController.text,
        'url_foto': imageUrl,
        'fecha': DateTime.now().toUtc().toIso8601String(), // Guardar siempre en UTC
        'estado': '4' // Nueva
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al enviar: $e")),
        );
      }
    }
  }
}