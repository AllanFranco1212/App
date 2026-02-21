import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginPage extends StatefulWidget {
  final Function(String) onLoginSuccess; // Callback para avisar o main.dart

  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _validarLicenca() async {
    // 1. Oculta teclado e mostra loading
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    String usuarioInput = _userController.text.trim();
    String senhaInput = _passController.text.trim();

    if (usuarioInput.isEmpty || senhaInput.isEmpty) {
      _mostrarErro("Preencha usuário e senha");
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 2. Consulta o nó 'Licencas/usuario_digitado'
      final ref = FirebaseDatabase.instance.ref('Licencas/$usuarioInput');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        
        // 3. Validações de segurança baseadas na sua imagem
        String senhaReal = data['senha']?.toString() ?? "";
        bool isAtivo = data['ativo'] == true;

        if (senhaInput == senhaReal) {
          if (isAtivo) {
            // SUCESSO! Chama a função do main.dart para liberar o app
            widget.onLoginSuccess(usuarioInput); 
          } else {
            _mostrarErro("Licença inativa ou expirada.");
          }
        } else {
          _mostrarErro("Senha incorreta.");
        }
      } else {
        _mostrarErro("Usuário não encontrado.");
      }
    } catch (e) {
      _mostrarErro("Erro de conexão: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, size: 60, color: Colors.blueAccent),
              ),
              const SizedBox(height: 30),
              const Text(
                "Acesso ao Sistema",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              // Campo Usuário (ex: cliente_joao)
              TextField(
                controller: _userController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Usuário",
                  hintText: "User",
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: const Icon(Icons.person, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              // Campo Senha
              TextField(
                controller: _passController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),
              
              // Botão Entrar
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _validarLicenca,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20, width: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text("ACESSAR PAINEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}