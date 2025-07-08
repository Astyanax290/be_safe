import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  String _gender = 'male';
  DateTime? _birthDate;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() => _birthDate = selected);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final id = user.id;
    final name = _nameController.text.trim();

    try {
      await Supabase.instance.client
          .from('users')
          .update({'full_name': name})
          .eq('id', id);

      await Supabase.instance.client.from('profiles').upsert({
        'id': id,
        'gender': _gender,
        'birth_date': _birthDate?.toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la sauvegarde : $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty && _birthDate != null && !_loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Complète ton profil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Genre'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Masculin')),
                DropdownMenuItem(value: 'female', child: Text('Féminin')),
                DropdownMenuItem(value: 'other', child: Text('Autre')),
              ],
              onChanged: (v) => setState(() => _gender = v!),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Text(
                    _birthDate == null
                        ? 'Date de naissance'
                        : 'Né le : ${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: _pickBirthDate,
                  child: const Text('Choisir'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: canSave ? _saveProfile : null,
              child: Text(_loading ? 'Enregistrement...' : 'Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }
}
