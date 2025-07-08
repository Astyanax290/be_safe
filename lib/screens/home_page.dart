import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'map_page.dart'; // Assure-toi d’avoir ce fichier importé

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // 👇 Liste des widgets pour chaque onglet
  final List<Widget> _pages = const [
    MapPage(), // Localisation
    Center(child: Text('Fonctions de sécurité 🛡️')), // Sécurité
    Center(child: Text('Paramètres ⚙️')), // Paramètres
  ];

  // 🔐 Déconnexion sécurisée
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Be Safe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
        ],
      ),

      // 👇 Affiche le contenu selon l’onglet sélectionné
      body: _pages[_selectedIndex],

      // 🧭 Barre de navigation inférieure
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Localisation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: 'Sécurité',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
