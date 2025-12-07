import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class Task {
  final String name;
  final DateTime date;
  final String priority;
  final File? image;
  final String? imageUrl;
  Task({
    required this.name,
    required this.date,
    required this.priority,
    this.image,
    this.imageUrl,
  });
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
      void _addTaskWithPanelHide() async {
        await _addTask();
        setState(() {
          _showAddPanel = false;
        });
      }
    bool _showAddPanel = false;
  List<Task> _tasks = [];
  bool _loading = false;
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  String _priority = 'Normal';
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final Color navyBlue = const Color(0xFF0A2342);
  final Color navyBlueLight = const Color(0xFF185ADB);

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _loading = true);
    final url = Uri.parse('http://10.0.2.2:3000/tasks');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>;
        setState(() {
          _tasks = items.map((item) => Task(
            name: item['name'] ?? '',
            date: DateTime.tryParse(item['date'] ?? '') ?? DateTime.now(),
            priority: item['priority'] ?? 'Normal',
            image: item['imageUrl'] != null && item['imageUrl'] != ''
                ? File('') // Placeholder, será carregada via network
                : null,
            imageUrl: item['imageUrl'],
          )).toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Selecionar da Galeria'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setState(() {
                      _imageFile = File(pickedFile.path);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tirar Foto'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await _picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    setState(() {
                      _imageFile = File(pickedFile.path);
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light(), // Calendário com fundo branco
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _addTask() async {
    if (_nameController.text.isEmpty || _selectedDate == null) return;
    final task = Task(
      name: _nameController.text,
      date: _selectedDate!,
      priority: _priority,
      image: _imageFile,
    );
    setState(() {
      _tasks.add(task);
      _nameController.clear();
      _selectedDate = null;
      _priority = 'Normal';
      _imageFile = null;
    });
    await _uploadTask(task);
  }

  Future<void> _uploadTask(Task task) async {
    var request = http.MultipartRequest('POST', Uri.parse('http://10.0.2.2:3000/task'));
    request.fields['name'] = task.name;
    request.fields['date'] = task.date.toIso8601String();
    request.fields['priority'] = task.priority;
    if (task.image != null) {
      request.files.add(await http.MultipartFile.fromPath('file', task.image!.path));
    }
    final response = await request.send();
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarefa enviada!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao enviar tarefa!')));
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final d = date;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tarefas com LocalStack'),
        foregroundColor: Colors.white,
        backgroundColor: navyBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTasks,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTasks,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Adicionar Tarefa', style: TextStyle(fontSize: 16, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navyBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setState(() => _showAddPanel = !_showAddPanel),
                  ),
                ),
                const SizedBox(height: 16),
                if (_showAddPanel)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: navyBlueLight.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: navyBlueLight.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nome da tarefa',
                            labelStyle: TextStyle(color: navyBlue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: navyBlueLight, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickDate,
                                child: AbsorbPointer(
                                  child: TextField(
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Data',
                                      labelStyle: TextStyle(color: navyBlue),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: navyBlueLight, width: 2),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(Icons.calendar_today, color: navyBlueLight),
                                        onPressed: _pickDate,
                                      ),
                                    ),
                                    controller: TextEditingController(
                                      text: _formatDate(_selectedDate),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: InputDecoration(
                            labelText: 'Prioridade',
                            labelStyle: TextStyle(color: navyBlue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: ['Baixa', 'Normal', 'Alta']
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) => setState(() => _priority = v!),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _imageFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(_imageFile!, height: 60, width: 60, fit: BoxFit.cover),
                                  )
                                : Container(
                                    height: 60,
                                    width: 60,
                                    decoration: BoxDecoration(
                                      color: navyBlueLight.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.image, color: Colors.grey, size: 32),
                                  ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: _pickImage,
                                icon: Icon(Icons.add_a_photo, color: navyBlueLight),
                                label: Text('Escolher Imagem', style: TextStyle(color: navyBlueLight)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _addTaskWithPanelHide,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navyBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Adicionar Tarefa', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Tarefas',
                  style: TextStyle(
                    color: navyBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 12),
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _tasks.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: Text(
                              'Nenhuma tarefa encontrada.',
                              style: TextStyle(color: navyBlueLight, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _tasks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final t = _tasks[i];
                              Widget leadingWidget;
                              if (t.image != null && t.image!.path.isEmpty && t.name.isNotEmpty) {
                                leadingWidget = FutureBuilder<Widget>(
                                  future: _buildNetworkImage(t),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                      return GestureDetector(
                                        onTap: () => _showImageDialog(context, t),
                                        child: SizedBox(
                                          height: 40,
                                          width: 40,
                                          child: snapshot.data!,
                                        ),
                                      );
                                    }
                                    return const SizedBox(
                                      height: 40,
                                      width: 40,
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    );
                                  },
                                );
                              } else if (t.image != null) {
                                leadingWidget = GestureDetector(
                                  onTap: () => _showImageDialog(context, t),
                                  child: SizedBox(
                                    height: 40,
                                    width: 40,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(t.image!, height: 40, width: 40, fit: BoxFit.cover),
                                    ),
                                  ),
                                );
                              } else {
                                leadingWidget = Icon(Icons.task_alt, color: navyBlueLight, size: 32);
                              }
                              return Container(
                                decoration: BoxDecoration(
                                  color: navyBlueLight.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: leadingWidget,
                                  title: Text(
                                    t.name,
                                    style: TextStyle(
                                      color: navyBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_formatDate(t.date)}  |  ${t.priority}',
                                    style: TextStyle(color: navyBlueLight, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              );
                            },
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, Task t) {
    showDialog(
      context: context,
      builder: (context) {
        Widget imageWidget;
        if (t.image != null && t.image!.path.isNotEmpty) {
          imageWidget = Image.file(t.image!, fit: BoxFit.contain);
        } else if (t.imageUrl != null && t.imageUrl!.isNotEmpty) {
          final url = 'http://10.0.2.2:4566/shopping-images/${t.imageUrl}';
          imageWidget = Image.network(url, fit: BoxFit.contain);
        } else {
          imageWidget = const Icon(Icons.broken_image, size: 80, color: Colors.grey);
        }
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: imageWidget,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Widget> _buildNetworkImage(Task t) async {
    // Use only the backend-provided imageUrl for S3 images
    if (t.imageUrl == null || t.imageUrl!.isEmpty) {
      return const Icon(Icons.broken_image, color: Colors.grey, size: 32);
    }
    final url = 'http://10.0.2.2:4566/shopping-images/${t.imageUrl}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(url, height: 40, width: 40, fit: BoxFit.cover),
    );
  }
}
