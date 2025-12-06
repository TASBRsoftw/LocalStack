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
  Task({required this.name, required this.date, required this.priority, this.image});
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final List<Task> _tasks = [];
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  String _priority = 'Normal';
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Tarefas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nome da tarefa'),
                ),
                Row(
                  children: [
                    Text(_selectedDate == null ? 'Selecione a data' : _selectedDate!.toLocal().toString().split(' ')[0]),
                    TextButton(onPressed: _pickDate, child: const Text('Escolher Data')),
                  ],
                ),
                DropdownButton<String>(
                  value: _priority,
                  items: ['Baixa', 'Normal', 'Alta'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
                Row(
                  children: [
                    _imageFile != null ? Image.file(_imageFile!, height: 50) : const Text('Nenhuma imagem'),
                    TextButton(onPressed: _pickImage, child: const Text('Escolher Imagem')),
                  ],
                ),
                ElevatedButton(onPressed: _addTask, child: const Text('Adicionar Tarefa')),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, i) {
                final t = _tasks[i];
                return ListTile(
                  leading: t.image != null ? Image.file(t.image!, height: 40) : null,
                  title: Text(t.name),
                  subtitle: Text('${t.date.toLocal().toString().split(' ')[0]} - ${t.priority}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
