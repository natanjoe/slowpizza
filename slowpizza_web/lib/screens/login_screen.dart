import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin_dashboard.dart';
import '../widgets/loading_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  void _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = await _authService.loginAdmin(
      _emailController.text,
      _passwordController.text,
    );

    setState(() {
      _loading = false;
    });

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) =>  AdminDashboard()),
      );
    } else {
      setState(() {
        _error = "Usuário ou senha inválidos, ou não é admin.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? const LoadingWidget()
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _login,
                      child: const Text('Login Admin'),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}