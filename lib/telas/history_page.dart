import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'bot_details_page.dart';

class HistoryPage extends StatefulWidget {
  final String usuario; // Recebe usuário
  const HistoryPage({super.key, required this.usuario});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late DatabaseReference _activeBotsRef;
  late DatabaseReference _configRef;

  @override
  void initState() {
    super.initState();
    // MUDANÇA: Caminhos dinâmicos
    _activeBotsRef = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Bots_Ativos');
    _configRef = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Configuracoes/Bots');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Painel de Robôs', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: _configRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final dynamic rawData = snapshot.data?.snapshot.value;
          if (rawData == null) {
            return const Center(child: Text("Nenhum bot cadastrado no momento", style: TextStyle(color: Colors.white54)));
          }

          // Proteção List vs Map para Config
          Map<dynamic, dynamic> botsConfigurados = {};
          List<String> botsList = [];
          if (rawData is Map) {
             botsConfigurados = rawData;
             botsList = rawData.keys.map((e) => e.toString()).toList();
          } else if (rawData is List) {
             for (int i=0; i<rawData.length; i++) {
               if(rawData[i] != null) {
                 String k = "Bot_${i+1}";
                 botsConfigurados[k] = rawData[i];
                 botsList.add(k);
               }
             }
          }
          botsList.sort();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: botsList.length,
            itemBuilder: (context, index) {
              String botId = botsList[index];
              final Map? config = botsConfigurados[botId];

              String rawStake = config?['stake']?.toString() ?? "---";
              String stakeFormatada = rawStake.contains('R\$')
                  ? rawStake.replaceFirst('R\$', 'R\$ ')
                  : (rawStake == "---" ? "---" : 'R\$ $rawStake');

              return StreamBuilder(
                // Listener do Saldo (mantido)
                stream: _activeBotsRef.child(botId).child('Conta').onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> saldoSnapshot) {
                  final Map? contaData = saldoSnapshot.data?.snapshot.value as Map?;
                  
                  String rawSaldo = contaData?['saldo_atual']?.toString() ?? "0,00";
                  String saldoFormatado = rawSaldo.contains('R\$') 
                      ? rawSaldo.replaceFirst('R\$', 'R\$ ') 
                      : 'R\$ $rawSaldo';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [const Color(0xFF1E293B), const Color(0xFF1E293B).withOpacity(0.8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.push(
                          context, 
                          // MUDANÇA: Passamos o usuário para a página de detalhes também
                          MaterialPageRoute(builder: (context) => BotDetailsPage(usuario: widget.usuario, botId: botId))
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      botId.replaceAll('_', ' ').toUpperCase(),
                                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    saldoFormatado,
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildModernInfo("SITE", config?['site'] ?? '---'),
                                  _buildModernInfo("STAKE", stakeFormatada),
                                  _buildModernInfo("ODD MÍN.", config?['limite_odd'] ?? '0.0'),
                                ],
                              ),
                              const SizedBox(height: 15),
                              const Divider(color: Colors.white10),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Ver histórico detalhado", style: TextStyle(color: Colors.white24, fontSize: 11)),
                                  Icon(Icons.keyboard_arrow_right, color: Colors.white24, size: 16),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildModernInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}