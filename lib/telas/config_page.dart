import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class ConfigPage extends StatefulWidget {
  final String usuario;
  const ConfigPage({super.key, required this.usuario});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late DatabaseReference _dbRef;
  bool _isLoading = false; 

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Configuracoes/Bots');
  }

  // --- Função: Enviar Comandos para o Python ---
  Future<void> _enviarComando(String comando, String mensagemSucesso) async {
    setState(() => _isLoading = true);
    
    final controleRef = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Configuracoes/Controle');
    
    try {
      await controleRef.update({
        'comando': comando, // 'REINICIAR_BOTS' ou 'LIMPAR_COOKIES'
        'timestamp': ServerValue.timestamp,
        'origem': 'APP_MOBILE'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemSucesso), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Popup de Confirmação ---
  void _confirmarLimpeza() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text("Atenção", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Confirmar limpeza de cookies?\n\nIsso desconectará as sessões salvas nos navegadores dos bots.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _enviarComando('LIMPAR_COOKIES', 'Comando: Limpar Cookies enviado!');
            },
            child: const Text("CONFIRMAR LIMPEZA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Configuração de Bots"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Lista de Bots
          Expanded(
            child: StreamBuilder(
              stream: _dbRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final dynamic rawData = snapshot.data?.snapshot.value;
                Map<dynamic, dynamic> botsGravados = {};
                
                if (rawData is Map) {
                  botsGravados = rawData;
                } else if (rawData is List) {
                  for (int i = 0; i < rawData.length; i++) {
                    if (rawData[i] != null) botsGravados["Bot_${i + 1}"] = rawData[i];
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    final String slotId = "Bot_${index + 1}";
                    final Map? dadosBot = botsGravados[slotId];
                    final bool estaConfigurado = dadosBot != null;
                    final bool isAtivo = dadosBot?['ativo'] == true;

                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          onTap: () => _abrirFormulario(slotId: slotId, dados: dadosBot),
                          leading: Container(
                            height: double.infinity,
                            child: Icon(
                              Icons.android,
                              color: estaConfigurado 
                                  ? (isAtivo ? Colors.greenAccent : Colors.white38) 
                                  : Colors.white10,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            estaConfigurado
                                ? "${dadosBot['site']}" 
                                : "$slotId (Disponível)",
                            style: TextStyle(
                              color: estaConfigurado ? Colors.white : Colors.white30,
                              fontWeight: estaConfigurado ? FontWeight.bold : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: estaConfigurado
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      "${dadosBot['usuario']}",
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Stake: R\$ ${dadosBot['stake']} | Modo: ${dadosBot['modo_operacao'] ?? 'Live'}",
                                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                                    ),
                                  ],
                                )
                              : const Text(
                                  "Clique para configurar",
                                  style: TextStyle(fontSize: 12, color: Colors.white54),
                                ),
                          trailing: estaConfigurado
                              ? Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: isAtivo,
                                    activeColor: Colors.white,
                                    activeTrackColor: Colors.greenAccent,
                                    inactiveThumbColor: Colors.white38,
                                    inactiveTrackColor: Colors.black26,
                                    onChanged: (bool value) {
                                      _dbRef.child(slotId).update({'ativo': value});
                                    },
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                                  onPressed: () => _abrirFormulario(slotId: slotId, dados: dadosBot),
                                ),
                          isThreeLine: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 2. Área Fixa Inferior
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A), 
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : () => _enviarComando('REINICIAR_BOTS', 'Reiniciando Bots...'),
                          icon: _isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)) 
                              : const Icon(Icons.restart_alt_rounded, color: Colors.redAccent),
                          label: Text(
                            _isLoading ? "ENVIANDO..." : "REINICIAR BOTS",
                            style: const TextStyle(
                              color: Colors.redAccent, 
                              fontWeight: FontWeight.bold, 
                              letterSpacing: 1.0,
                              fontSize: 13
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 60, 
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _confirmarLimpeza,
                        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Ações de controle do sistema.",
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFormulario({required String slotId, Map? dados}) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: dados?['usuario']?.toString() ?? '');
    final passController = TextEditingController(text: dados?['senha']?.toString() ?? '');
    final stakeController = TextEditingController(text: dados?['stake']?.toString() ?? '');
    final oddController = TextEditingController(text: dados?['limite_odd']?.toString() ?? '');
    final telegramController = TextEditingController(text: dados?['telegram_link']?.toString() ?? '');
    
    // --- NOVO: Inicializa o Range de Linhas ---
    double initialRange = double.tryParse(dados?['range_linhas']?.toString() ?? '0.0') ?? 0.0;
    final rangeController = TextEditingController(text: initialRange.toStringAsFixed(2));
    
    bool currentAtivo = dados?['ativo'] ?? true; 

    // --- LÓGICA DO SITE ---
    String valorBancoSite = dados?['site']?.toString() ?? 'Betano';
    final List<String> sitesPermitidos = ['Betano', 'Novibet', 'SuperBet', 'Vavada'];
    String siteSelecionado = sitesPermitidos.contains(valorBancoSite) ? valorBancoSite : 'Betano';

    // --- LÓGICA: MODO DE OPERAÇÃO ---
    String valorBancoModo = dados?['modo_operacao']?.toString() ?? 'Live';
    final List<String> modosPermitidos = ['Pré', 'Live', 'Ambos'];
    String modoSelecionado = modosPermitidos.contains(valorBancoModo) ? valorBancoModo : 'Live';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Configurar ${slotId.replaceAll('_', ' ')}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: siteSelecionado,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: sitesPermitidos
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) => siteSelecionado = val!,
                  decoration: const InputDecoration(labelText: "Site", filled: true, fillColor: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "E-mail", filled: true, fillColor: Color(0xFF1E293B)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o e-mail' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Senha", filled: true, fillColor: Color(0xFF1E293B)),
                  obscureText: true,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a senha' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: telegramController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Link ou ID (Telegram)", filled: true, fillColor: Color(0xFF1E293B)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o link' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: stakeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Stake (R\$)", filled: true, fillColor: Color(0xFF1E293B)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))],
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: oddController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Limite ODD", filled: true, fillColor: Color(0xFF1E293B)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))],
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ============================================================
                // --- NOVO CAMPO: RANGE DE LINHAS (COM BOTÕES) ---
                // ============================================================
                // ============================================================
                // --- NOVO CAMPO: RANGE DE LINHAS (CORRIGIDO) ---
                // ============================================================
                // ============================================================
                // --- CAMPO RANGE DE LINHAS (SEM EXPANDED) ---
                // ============================================================
                StatefulBuilder(
                  builder: (context, setStateModal) {
                    return TextFormField(
                      controller: rangeController,
                      style: const TextStyle(color: Colors.white),
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Range de Linhas (0.00 - 2.00)", 
                        filled: true, 
                        fillColor: const Color(0xFF1E293B),
                        prefixIcon: const Icon(Icons.tune, color: Colors.blueAccent, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        suffixIcon: Container(
                          width: 40,
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: Colors.white10))
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min, // IMPORTANTE: Ocupa apenas o tamanho dos ícones
                            children: [
                              // Botão CIMA
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    double val = double.tryParse(rangeController.text) ?? 0.0;
                                    if (val < 2.00) {
                                      val += 0.25;
                                      setStateModal(() {
                                        rangeController.text = val.toStringAsFixed(2);
                                      });
                                    }
                                  },
                                  child: const Icon(Icons.arrow_drop_up, color: Colors.blueAccent, size: 24),
                                ),
                              ),
                              // Botão BAIXO
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    double val = double.tryParse(rangeController.text) ?? 0.0;
                                    if (val > 0.00) {
                                      val -= 0.25;
                                      setStateModal(() {
                                        rangeController.text = val.toStringAsFixed(2);
                                      });
                                    }
                                  },
                                  child: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent, size: 24),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                ),
                // ============================================================

                const SizedBox(height: 10),
                
                DropdownButtonFormField<String>(
                  value: modoSelecionado,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Modo de Operação", 
                    filled: true, 
                    fillColor: Color(0xFF1E293B),
                    prefixIcon: Icon(Icons.settings_input_component_rounded, color: Colors.blueAccent, size: 20),
                  ),
                  items: modosPermitidos
                      .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) => modoSelecionado = val!,
                ),
                
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blueAccent,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await _dbRef.child(slotId).set({
                        'usuario': emailController.text.trim(),
                        'senha': passController.text.trim(),
                        'site': siteSelecionado,
                        'stake': stakeController.text.trim(),
                        'limite_odd': oddController.text.trim(),
                        'telegram_link': telegramController.text.trim(),
                        'ativo': currentAtivo,
                        'modo_operacao': modoSelecionado,
                        'range_linhas': rangeController.text.trim(), // Salvando o novo campo
                      });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text("SALVAR CONFIGURAÇÃO", style: TextStyle(color: Colors.white)),
                ),
                if (dados != null)
                  TextButton(
                    onPressed: () async {
                      await _dbRef.child(slotId).remove();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text("Excluir/Resetar Slot", style: TextStyle(color: Colors.redAccent)),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}