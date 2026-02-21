import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'conversion_report_page.dart'; // IMPORTANTE: Importe a nova tela

class AnalyticsPage extends StatefulWidget {
  final String usuario;
  const AnalyticsPage({super.key, required this.usuario});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String selectedBot = "Todos os Bots";
  final NumberFormat f = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    final refBots = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Bots_Ativos');
    final refSinais = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Auditoria/Sinais_Recebidos');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Relatório de Eficiência"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: refBots.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshotBots) {
          if (snapshotBots.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          int vitorias = 0;
          int derrotas = 0;
          double somaOdds = 0.0;
          double lucroLiquido = 0.0;
          double totalInvestido = 0.0;
          int totalApostasGerais = 0;
          
          List<String> botKeys = ["Todos os Bots"];
          Map<String, String> displayNames = {"Todos os Bots": "Todos os Bots"};
          Map<String, dynamic> mapaTodosBots = {};

          if (snapshotBots.hasData && snapshotBots.data!.snapshot.value != null) {
            final dynamic botsRaw = snapshotBots.data!.snapshot.value;
            
            if (botsRaw is Map) {
              final bots = Map<String, dynamic>.from(botsRaw);
              mapaTodosBots = bots;
              
              List<String> tempKeys = bots.keys.toList();
              tempKeys.sort((a, b) => b.compareTo(a)); 
              botKeys.addAll(tempKeys);

              bots.forEach((botKey, botDataRaw) {
                if (botDataRaw is! Map) return;
                final botData = Map<String, dynamic>.from(botDataRaw);
                
                String site = botData['site']?.toString() ?? ""; 
                String nomeFormatado = botKey.replaceAll('_', ' ');
                if (site.isNotEmpty) nomeFormatado = "$nomeFormatado - $site";
                displayNames[botKey] = nomeFormatado;

                // Loop Financeiro
                if (selectedBot == "Todos os Bots" || selectedBot == botKey) {
                  final historicoRaw = botData['Historico_de_Apostas'];
                  if (historicoRaw != null && historicoRaw is Map) {
                    final historico = Map<String, dynamic>.from(historicoRaw);
                    historico.forEach((key, apostaRaw) {
                      if (apostaRaw is! Map) return; 
                      final aposta = Map<String, dynamic>.from(apostaRaw);
                      
                      totalApostasGerais++;
                      double stake = _parseMoney(aposta['Stake'] ?? aposta['stake']);
                      double odd = _parseMoney(aposta['ODD'] ?? aposta['odd']);
                      String res = (aposta['Resultado'] ?? aposta['resultado'])?.toString().toUpperCase() ?? "";

                      totalInvestido += stake;
                      somaOdds += odd;

                      if (res.contains("GREEN")) {
                        vitorias++;
                        lucroLiquido += (stake * odd) - stake;
                      } else if (res.contains("RED")) {
                        derrotas++;
                        lucroLiquido -= stake;
                      }
                    });
                  }
                }
              });
            }
          }

          double oddMedia = totalApostasGerais > 0 ? somaOdds / totalApostasGerais : 0.0;
          double roi = totalInvestido > 0 ? (lucroLiquido / totalInvestido) * 100 : 0.0;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBotSelector(botKeys, displayNames),
                      
                      _buildMainStat("LUCRO LÍQUIDO ACUMULADO", f.format(lucroLiquido), 
                          lucroLiquido >= 0 ? Colors.greenAccent : Colors.redAccent),
                      const SizedBox(height: 20),

                      // Stream Sinais
                      StreamBuilder(
                        stream: refSinais.onValue,
                        builder: (context, AsyncSnapshot<DatabaseEvent> snapSinais) {
                          int sinaisTotal = 0;
                          int convertidos = 0;

                          if (snapSinais.hasData && snapSinais.data!.snapshot.value != null) {
                            final dynamic sinaisRaw = snapSinais.data!.snapshot.value;
                            if (sinaisRaw is Map) {
                              final sinaisMap = Map<String, dynamic>.from(sinaisRaw);

                              sinaisMap.forEach((sKey, sValRaw) {
                                if (sValRaw is! Map) return;
                                final sVal = Map<String, dynamic>.from(sValRaw);
                                
                                String botDoSinal = sVal['Bot_Responsavel']?.toString() ?? "";
                                
                                bool deveContar = false;
                                if (selectedBot == "Todos os Bots") {
                                  deveContar = true;
                                } else {
                                  if (botDoSinal == selectedBot || botDoSinal.contains("Multiplos")) {
                                    deveContar = true;
                                  }
                                }

                                if (deveContar) {
                                  sinaisTotal++;
                                  bool matchEncontrado = false;
                                  mapaTodosBots.forEach((bKey, bValRaw) {
                                    if (matchEncontrado) return;
                                    if (selectedBot != "Todos os Bots" && bKey != selectedBot) return;
                                    if (!botDoSinal.contains("Multiplos") && botDoSinal.isNotEmpty && bKey != botDoSinal) return;
                                    if (bValRaw is! Map) return;
                                    
                                    final botData = Map<String, dynamic>.from(bValRaw);
                                    final histRaw = botData['Historico_de_Apostas'];
                                    if (histRaw != null && histRaw is Map) {
                                      final hist = Map<String, dynamic>.from(histRaw);
                                      hist.forEach((aKey, aValRaw) {
                                        if (matchEncontrado) return;
                                        if (aValRaw is! Map) return;
                                        final aVal = Map<String, dynamic>.from(aValRaw);
                                        if (_verificarMatch(sVal, aVal)) matchEncontrado = true;
                                      });
                                    }
                                  });
                                  if (matchEncontrado) convertidos++;
                                }
                              });
                            }
                          }

                          double capRate = sinaisTotal > 0 ? (convertidos / sinaisTotal) * 100 : 0;

                          return Row(
                            children: [
                              Expanded(child: _buildSmallStat("Sinais Recebidos", "$sinaisTotal", Icons.sensors, Colors.orangeAccent)),
                              const SizedBox(width: 15),
                              Expanded(child: _buildSmallStat("Eficiência Captação", "${capRate.toStringAsFixed(1)}%", Icons.bolt_rounded, Colors.blueAccent)),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 15),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.4,
                        children: [
                          _buildSmallStat("ROI", "${roi.toStringAsFixed(2)}%", Icons.trending_up, Colors.blueAccent),
                          _buildSmallStat("ODD Média", oddMedia.toStringAsFixed(2), Icons.analytics_outlined, Colors.purpleAccent),
                          _buildSmallStat("Greens", "$vitorias", Icons.check_circle_outline, Colors.greenAccent),
                          _buildSmallStat("Reds", "$derrotas", Icons.highlight_off, Colors.redAccent),
                        ],
                      ),

                      // ========================================================
                      // === NOVO BOTÃO DE RELATÓRIO CRUZADO (ÁREA VERMELHA) ===
                      // ========================================================
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.blueAccent.withOpacity(0.4)),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ConversionReportPage(
                                  usuario: widget.usuario,
                                  botSelecionado: selectedBot, // Passa o bot selecionado
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.compare_arrows, color: Colors.blueAccent),
                          label: const Text(
                            "VISUALIZAR CONVERSÃO",
                            style: TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 14,
                              letterSpacing: 1.0
                            ),
                          ),
                        ),
                      ),
                      // ========================================================
                    ],
                  ),
                ),
              ),
              _buildBottomBar(vitorias, derrotas),
            ],
          );
        },
      ),
    );
  }

  // --- Funções Auxiliares (Mantidas para o resumo da tela) ---
  bool _verificarMatch(Map sinal, Map aposta) {
    DateTime hSinal = _parseDateFlexivel(sinal['Data_Horario_Original']);
    DateTime hAposta = _parseDateFlexivel(aposta['Data_Horario_Original'] ?? aposta['horario']);
    int diff = hAposta.difference(hSinal).inMinutes; // Removi .abs() para garantir ordem
    if (diff < -2 || diff > 12) return false; 
    
    String strSinal = _normalize(sinal['Partida']);
    String strAposta = _normalize(aposta['Partida'] ?? aposta['partida']);
    // Limpa parenteses na comparação do resumo também
    String apostaLimpa = strAposta.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();

    List<String> tokensSinal = strSinal.split(' ').where((w) => w.length > 2 && w != 'vs').toList();
    for (String token in tokensSinal) {
      if (apostaLimpa.contains(token)) return true;
    }
    return false;
  }

  String _normalize(dynamic text) {
    if (text == null) return "";
    return text.toString().toLowerCase()
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .replaceAll('-', ' ')
        .replaceAll('—', ' ') 
        .replaceAll(RegExp(r'\s+'), ' ') 
        .trim();
  }

  DateTime _parseDateFlexivel(dynamic v) {
    if (v == null) return DateTime.now();
    String s = v.toString().replaceAll('-', '/'); 
    try {
      s = s.replaceAll(' / ', ' ').replaceAll(' - ', ' ').trim();
      if (s.split(':').length == 3) return DateFormat("dd/MM/yyyy HH:mm:ss").parseLoose(s);
      return DateFormat("dd/MM/yyyy HH:mm").parseLoose(s);
    } catch (e) {
      return DateTime.now();
    }
  }

  double _extractNumber(dynamic v) {
    final match = RegExp(r"(\d+(\.\d+)?)").firstMatch(v?.toString() ?? "0");
    return double.tryParse(match?.group(0) ?? "0") ?? 0.0;
  }

  double _parseMoney(dynamic v) => double.tryParse(v?.toString().replaceAll('R\$', '').replaceAll(' ', '').replaceAll(',', '.') ?? "0") ?? 0.0;

  Widget _buildBotSelector(List<String> keys, Map<String, String> displayMap) {
    return SizedBox(
      width: 240,
      child: Opacity(
        opacity: 0.7,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedBot,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              icon: const Icon(Icons.filter_list, color: Colors.blueAccent, size: 18),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              selectedItemBuilder: (BuildContext context) {
                return keys.map<Widget>((String key) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      displayMap[key] ?? key,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList();
              },
              items: keys.map((key) => DropdownMenuItem(
                value: key, 
                child: Text(displayMap[key] ?? key)
              )).toList(),
              onChanged: (val) => setState(() => selectedBot = val!),
            ),
          ),
        ),
      ),
    );
  }

  // --- Widgets Estatísticos ---
  Widget _buildMainStat(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int wins, int losses) {
    int total = wins + losses;
    double winWidth = total > 0 ? wins / total : 0.5;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
      decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ASSERTIVIDADE VISUAL", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(flex: (winWidth * 1000).toInt(), child: Container(color: Colors.greenAccent)),
                  Expanded(flex: ((1 - winWidth) * 1000).toInt(), child: Container(color: Colors.redAccent.withValues(alpha: 0.4))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Wins: $wins", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              Text("Losses: $losses", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}