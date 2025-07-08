import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // 🔐 Contrôleurs pour les champs
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 🔄 États de l'interface
  bool isLogin = true;
  bool loading = false;
  bool resendSent = false;
  bool awaitingEmailConfirmation = false;
  DateTime? _lastResendTime;

  // ✅ Vérifie la validité du mot de passe
  bool get isPasswordOk => isPasswordValid(_passwordController.text);

  // ✅ Vérifie que l'email a un format correct
  bool get isEmailOk => isEmailValid(_emailController.text);

  // ✅ Vérifie que le mot de passe est valide
  bool isPasswordValid(String password) {
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'\d'));
    final hasMinLength = password.length >= 6;
    return hasUppercase && hasDigit && hasMinLength;
  }

  // ✅ Vérifie que le format de l'e-mail est bon
  bool isEmailValid(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🔐 Connexion ou inscription
  Future<void> handleAuth() async {
    setState(() => loading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    try {
      // ❌ Email invalide
      if (!isEmailValid(email)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Adresse e-mail invalide.")),
        );
        setState(() => loading = false);
        return;
      }

      if (isLogin) {
        // 🔐 Tentative de connexion
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        final user = response.user;

        if (!mounted) return;

        if (user != null && user.emailConfirmedAt != null) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Veuillez confirmer votre email avant de vous connecter.")),
          );
          await Supabase.instance.client.auth.signOut();
          setState(() {
            awaitingEmailConfirmation = true;
          });
        }
      } else {
        // 🔒 Vérifie que les mots de passe correspondent
        if (password != confirmPassword) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Les mots de passe ne correspondent pas.")),
          );
          setState(() => loading = false);
          return;
        }

        // ❌ Mot de passe trop faible
        if (!isPasswordValid(password)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Mot de passe : min. 6 caractères, 1 majuscule et 1 chiffre."),
            ),
          );
          setState(() => loading = false);
          return;
        }

        // ✅ Inscription Supabase
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );

        final user = response.user;

        if (!mounted) return;

        if (user != null && user.emailConfirmedAt != null) {
          Navigator.pushReplacementNamed(context, '/profile');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Un lien de confirmation a été envoyé par email.")),
          );
          setState(() {
            awaitingEmailConfirmation = true;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // 🔁 Renvoyer le mail de confirmation
  Future<void> resendEmailConfirmation() async {
    final email = _emailController.text.trim();

    if (!isEmailValid(email)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Entrez un e-mail valide avant de renvoyer.")),
      );
      return;
    }

    if (resendSent && _lastResendTime != null) {
      final diff = DateTime.now().difference(_lastResendTime!);
      if (diff.inMinutes < 10) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veuillez patienter ${10 - diff.inMinutes} minute(s) avant de réessayer.'),
          ),
        );
        return;
      }
    }

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.email,
        email: email,
      );

      _lastResendTime = DateTime.now();
      resendSent = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("E-mail de confirmation renvoyé.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPasswordValidation = !isLogin && _passwordController.text.isNotEmpty;
    final showEmailValidation = !isEmailOk && _emailController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔷 Titre
                Text(
                  isLogin ? 'Connexion' : 'Inscription',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                // 📧 Email
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
                if (showEmailValidation)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Adresse e-mail invalide.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                const SizedBox(height: 12),

                // 🔑 Mot de passe
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),
                if (showPasswordValidation && !isPasswordOk)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Min. 6 caractères, 1 majuscule, 1 chiffre",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                // 🔒 Confirmation mot de passe
                if (!isLogin)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Confirmer le mot de passe"),
                    ),
                  ),

                const SizedBox(height: 20),

                // 🚀 Bouton principal
                ElevatedButton(
                  onPressed: loading ? null : handleAuth,
                  child: Text(
                    loading
                        ? 'Chargement...'
                        : (isLogin ? 'Se connecter' : 'S’inscrire'),
                  ),
                ),

                const SizedBox(height: 10),

                // 🔄 Changer de mode
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                      awaitingEmailConfirmation = false;
                      resendSent = false;
                    });
                  },
                  child: Text(
                    isLogin
                        ? "Pas encore de compte ? S'inscrire"
                        : "Déjà un compte ? Se connecter",
                  ),
                ),

                // 📩 Renvoyer le mail de confirmation uniquement dans les bons cas
                if (awaitingEmailConfirmation)
                  TextButton(
                    onPressed: resendEmailConfirmation,
                    child: const Text("Renvoyer l’e-mail de confirmation"),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
