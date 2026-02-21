import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class UserLicensePage extends StatefulWidget {
  final String usuario;
  const UserLicensePage({super.key, required this.usuario});

  @override
  State<UserLicensePage> createState() => _UserLicensePageState();
}

class _UserLicensePageState extends State<UserLicensePage> {
  late DatabaseReference _telegramRef;
  
  final _formKey = GlobalKey<FormState>();
  final _apiIdController = TextEditingController();
  final _apiHashController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Define o caminho onde as credenciais do Telegram serão salvas
    _telegramRef = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Configuracoes/Telegram');
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final snapshot = await _telegramRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        _apiIdController.text = data['api_id']?.toString() ?? '';
        _apiHashController.text = data['api_hash']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarDados() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // O api_id geralmente é número, mas salvamos como string ou int, o Telegram aceita ambos no json
      await _telegramRef.update({
        'api_id': int.tryParse(_apiIdController.text) ?? _apiIdController.text, 
        'api_hash': _apiHashController.text.trim(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Credenciais do Telegram salvas com sucesso!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Volta para o menu
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Credenciais Telegram"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Informativo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blueAccent),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Essas credenciais são necessárias para conectar o Bot à sua conta do Telegram. Obtenha em my.telegram.org",
                              style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    const Text("Configuração da API", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Campo API ID
                    TextFormField(
                      controller: _apiIdController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration("API ID (Somente números)"),
                      validator: (v) => v == null || v.isEmpty ? "Informe o API ID" : null,
                    ),
                    const SizedBox(height: 16),

                    // Campo API HASH
                    TextFormField(
                      controller: _apiHashController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("API HASH"),
                      validator: (v) => v == null || v.isEmpty ? "Informe o API HASH" : null,
                    ),
                    
                    const SizedBox(height: 40),

                    // Botão Salvar
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _salvarDados,
                        child: const Text("SALVAR CREDENCIAIS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blueAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: const Color(0xFF1E293B),
    );
  }
}