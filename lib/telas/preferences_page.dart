import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PreferencesPage extends StatefulWidget {
  final String usuario;
  const PreferencesPage({super.key, required this.usuario});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late DatabaseReference _prefRef;

  @override
  void initState() {
    super.initState();
    _prefRef = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Configuracoes/Mecanismo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Preferências & Logs'), 
        backgroundColor: Colors.transparent,
        elevation: 0
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- SEÇÃO 1: CONFIGURAÇÕES EXISTENTES ---
            StreamBuilder(
              stream: _prefRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                final data = (snapshot.data?.snapshot.value as Map?) ?? {};

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildPrefTile(
                            icon: Icons.cloud_upload,
                            title: "Tempo de Push (Firebase)",
                            value: "${data['tempo_push'] ?? 10}s",
                            onTap: () => _editValue(context, _prefRef, "tempo_push", "Segundos"),
                          ),
                          const SizedBox(height: 10),
                          _buildPrefTile(
                            icon: Icons.timer,
                            title: "Timeout de Apostas",
                            value: "${data['timeout_apostas'] ?? 30}s",
                            onTap: () => _editValue(context, _prefRef, "timeout_apostas", "Segundos"),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            color: const Color(0xFF1E293B),
                            child: SwitchListTile(
                              title: const Text("Notificações Push", style: TextStyle(color: Colors.white)),
                              secondary: const Icon(Icons.notifications, color: Colors.blueAccent),
                              value: data['notificacoes'] ?? true,
                              activeColor: Colors.blueAccent,
                              onChanged: (val) => _prefRef.update({'notificacoes': val}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const Divider(color: Colors.white10, height: 30),

            // --- SEÇÃO 2: TERMINAL DE LOGS (NOVO) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TERMINAL DE LOGS (AO VIVO)",
                    style: TextStyle(
                      color: Colors.white54, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 1.2
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Passamos o usuário para buscar os logs de todos os bots
                  TerminalLogsWidget(usuario: widget.usuario),
                  const SizedBox(height: 30), // Espaço final
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefTile({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return Card(
      color: const Color(0xFF1E293B),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const Icon(Icons.edit, size: 16, color: Colors.white24)
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _editValue(BuildContext context, DatabaseReference ref, String key, String label) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Ajustar $label", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Valor atual...", 
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.update({key: int.parse(controller.text)});
                Navigator.pop(context);
              }
            },
            child: const Text("SALVAR", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET DO TERMINAL (NOVO)
// ============================================================================
class TerminalLogsWidget extends StatelessWidget {
  final String usuario;
  const TerminalLogsWidget({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    // Escuta o nó "Bots_Ativos" inteiro para pegar logs de todos os bots de uma vez
    final botsRef = FirebaseDatabase.instance.ref('Licencas/$usuario/Bots_Ativos');

    return Container(
      height: 400, // Altura fixa para simular uma janela de terminal
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117), // Cor estilo VS Code / Terminal
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: StreamBuilder(
          stream: botsRef.onValue,
          builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }

            // 1. Processamento e Fusão dos Logs
            List<Map<String, dynamic>> allLogs = [];

            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              final dynamic rawData = snapshot.data!.snapshot.value;
              
              if (rawData is Map) {
                // Itera sobre cada Bot (Bot_1, Bot_2, etc.)
                rawData.forEach((botId, botData) {
                  if (botData is Map && botData['Logs'] != null) {
                    final logsMap = botData['Logs'] as Map;
                    
                    logsMap.forEach((logKey, logValue) {
                      if (logValue is Map) {
                        final logItem = Map<String, dynamic>.from(logValue);
                        logItem['bot_id'] = botId; // Injeta o ID do bot no log
                        allLogs.add(logItem);
                      }
                    });
                  }
                });
              }
            }

            if (allLogs.isEmpty) {
              return const Center(
                child: Text(
                  ">_ Aguardando logs do sistema...", 
                  style: TextStyle(color: Colors.white24, fontFamily: 'monospace')
                )
              );
            }

            // 2. Ordenação (Do mais recente para o mais antigo)
            // Usa o timestamp do servidor se existir, senão tenta usar data/hora string
            allLogs.sort((a, b) {
              int timeA = a['timestamp'] ?? 0;
              int timeB = b['timestamp'] ?? 0;
              return timeB.compareTo(timeA); // Descendente
            });

            // 3. Renderização da Lista
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: allLogs.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final log = allLogs[index];
                return _buildLogLine(log);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogLine(Map<String, dynamic> log) {
    // Formatação dos Dados
    String botIdRaw = log['bot_id']?.toString() ?? "???";
    String botDisplay = "[${botIdRaw.replaceAll('_', ' ').toUpperCase()}]"; // [BOT 1]
    
    // Tratamento de Data/Hora (Vem do Python como YYYY-MM-DD e HH:mm:ss)
    String data = log['data']?.toString() ?? "";
    String hora = log['hora']?.toString() ?? "";
    
    // Converte 2026-01-20 para 20/01
    String dataCurta = data;
    if (data.contains('-') && data.length >= 10) {
      final parts = data.split('-');
      if (parts.length == 3) {
        dataCurta = "${parts[2]}/${parts[1]}";
      }
    }
    
    String timestampDisplay = "$dataCurta - $hora"; // 20/01 - 20:45:42
    String mensagem = log['mensagem']?.toString() ?? "";
    String nivel = log['nivel']?.toString().toUpperCase() ?? "INFO";

    // Definição de Cores Baseado no Nível
    Color msgColor;
    Color iconColor;
    
    switch (nivel) {
      case 'ERROR':
        msgColor = Colors.redAccent;
        iconColor = Colors.red;
        break;
      case 'WARNING':
        msgColor = Colors.orangeAccent;
        iconColor = Colors.orange;
        break;
      case 'SUCCESS':
        msgColor = Colors.greenAccent;
        iconColor = Colors.green;
        break;
      default: // INFO
        msgColor = const Color(0xFFE0E0E0); // Cinza claro/Branco
        iconColor = Colors.blueAccent;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timestamp e Bot ID (Estilo Monospace)
        Text(
          "$botDisplay $timestampDisplay: ",
          style: TextStyle(
            color: Colors.blueGrey[300],
            fontSize: 11,
            fontFamily: 'monospace', // Fonte de terminal
            fontWeight: FontWeight.bold
          ),
        ),
        
        // Mensagem
        Expanded(
          child: Text(
            mensagem,
            style: TextStyle(
              color: msgColor,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.1 // Espaçamento de linha apertado
            ),
          ),
        ),
      ],
    );
  }
}