import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ConversionReportPage extends StatefulWidget {
  final String usuario;
  final String botSelecionado; // Recebe o filtro da tela anterior

  const ConversionReportPage({
    super.key, 
    required this.usuario,
    required this.botSelecionado,
  });

  @override
  State<ConversionReportPage> createState() => _ConversionReportPageState();
}

class _ConversionReportPageState extends State<ConversionReportPage> {
  final NumberFormat f = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    // Referências ao Firebase
    final refBots = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Bots_Ativos');
    final refSinais = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Auditoria/Sinais_Recebidos');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Relatório de Conversão", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.botSelecionado, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: refBots.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshotBots) {
          if (snapshotBots.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 1. Carregar Histórico do(s) Bot(s) Relevante(s)
          Map<String, dynamic> historicoGlobal = {}; 
          
          if (snapshotBots.hasData && snapshotBots.data!.snapshot.value != null) {
            final dynamic botsRaw = snapshotBots.data!.snapshot.value;
            if (botsRaw is Map) {
              botsRaw.forEach((botKey, botData) {
                // Filtra: Só carrega histórico se for "Todos" ou se for o Bot específico
                if (widget.botSelecionado == "Todos os Bots" || widget.botSelecionado == botKey) {
                  if (botData is Map && botData['Historico_de_Apostas'] != null) {
                    historicoGlobal[botKey] = botData['Historico_de_Apostas'];
                  }
                }
              });
            }
          }

          // 2. Carregar Sinais e Cruzar
          return StreamBuilder(
            stream: refSinais.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshotSinais) {
              if (snapshotSinais.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshotSinais.hasData || snapshotSinais.data!.snapshot.value == null) {
                return const Center(child: Text("Nenhum sinal encontrado.", style: TextStyle(color: Colors.white54)));
              }

              List<Map<String, dynamic>> listaRelatorio = [];
              final dynamic sinaisRaw = snapshotSinais.data!.snapshot.value;

              if (sinaisRaw is Map) {
                // Ordenar chaves
                var sortedKeys = sinaisRaw.keys.toList()..sort((a, b) => b.toString().compareTo(a.toString()));

                for (var key in sortedKeys) {
                  final sinal = Map<String, dynamic>.from(sinaisRaw[key]);
                  String botDoSinal = sinal['Bot_Responsavel']?.toString() ?? "";

                  // --- FILTRO DE EXIBIÇÃO ---
                  // Se estou vendo "Bot 1", quero ver sinais do "Bot 1" e sinais "Multiplos"
                  bool deveMostrar = false;
                  if (widget.botSelecionado == "Todos os Bots") {
                    deveMostrar = true;
                  } else {
                    if (botDoSinal == widget.botSelecionado || botDoSinal.contains("Multiplos")) {
                      deveMostrar = true;
                    }
                  }

                  if (deveMostrar) {
                    // --- LÓGICA DE CRUZAMENTO (MATCHING) ---
                    Map<String, dynamic>? apostaEncontrada = _buscarApostaCorrespondente(sinal, historicoGlobal);
                    
                    listaRelatorio.add({
                      'sinal': sinal,
                      'convertido': apostaEncontrada != null,
                      'aposta': apostaEncontrada
                    });
                  }
                }
              }

              if (listaRelatorio.isEmpty) {
                return const Center(child: Text("Nenhum sinal para este filtro.", style: TextStyle(color: Colors.white54)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: listaRelatorio.length,
                itemBuilder: (context, index) {
                  return _buildConversionCard(listaRelatorio[index]);
                },
              );
            },
          );
        },
      ),
    );
  }

  // === LÓGICA DE INTELIGÊNCIA: SINAL vs HISTÓRICO ===
  Map<String, dynamic>? _buscarApostaCorrespondente(Map sinal, Map<String, dynamic> historicoGlobal) {
    // Percorre o histórico carregado (que já está filtrado pelo bot selecionado)
    for (String botId in historicoGlobal.keys) {
      final historicoBot = historicoGlobal[botId];
      if (historicoBot is Map) {
        for (var entry in historicoBot.entries) {
          final aposta = Map<String, dynamic>.from(entry.value);
          
          if (_verificarMatch(sinal, aposta)) {
            aposta['bot_origem'] = botId; // Marca quem fez a aposta
            return aposta;
          }
        }
      }
    }
    return null;
  }

  bool _verificarMatch(Map sinal, Map aposta) {
    // 1. DATA (Range de 12 minutos)
    DateTime hSinal = _parseDateFlexivel(sinal['Data_Horario_Original']);
    DateTime hAposta = _parseDateFlexivel(aposta['Data_Horario_Original'] ?? aposta['horario']);
    
    // Diferença em minutos
    int diff = hAposta.difference(hSinal).inMinutes;
    
    // A aposta deve ser feita DEPOIS do sinal, mas não mais que 12 min depois.
    // Aceitamos -2 min de tolerância para diferenças de relógio servidor/bot.
    if (diff < -2 || diff > 12) return false; 

    // 2. LIMPEZA DE NOMES (Remover parenteses dos Players)
    // Sinal: "leon vs razvan"
    // Aposta: "Liga: GT | Leon vs Razvan" ou "Leon (P1) - Razvan (P2)"
    String strSinal = _normalize(sinal['Partida']);
    String strAposta = _normalize(aposta['Partida'] ?? aposta['partida']);

    // Remove qualquer coisa entre parenteses na aposta para limpar " (Lucas)" ou " (Vendetta)"
    String apostaLimpa = strAposta.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();

    // Quebra o nome do sinal em partes (ex: "leon", "razvan")
    List<String> tokensSinal = strSinal.split(' ').where((w) => w.length > 2 && w != 'vs').toList();
    
    // Verifica se os nomes do sinal existem na aposta
    int matches = 0;
    for (String token in tokensSinal) {
      if (apostaLimpa.contains(token)) matches++;
    }

    // Se encontrou nomes coincidentes, é Match!
    if (matches > 0) return true;

    return false;
  }

  String _normalize(dynamic text) {
    if (text == null) return "";
    return text.toString().toLowerCase()
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

  // === VISUALIZAÇÃO ===
  Widget _buildConversionCard(Map<String, dynamic> item) {
    final sinal = item['sinal'];
    final aposta = item['aposta'];
    final bool convertido = item['convertido'];

    final Color statusColor = convertido ? Colors.greenAccent : Colors.redAccent;
    final IconData statusIcon = convertido ? Icons.check_circle : Icons.cancel;
    final String statusText = convertido ? "CONVERTIDO EM APOSTA" : "NÃO CONVERTIDO / IGNORADO";

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(statusIcon, color: statusColor, size: 28),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white54,
        title: Text(
          sinal['Partida'] ?? "Jogo Desconhecido",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              statusText,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              "Sinal: ${sinal['Data_Horario_Original']}",
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("DADOS DO SINAL RECEBIDO", Colors.orangeAccent),
                _buildInfoRow("Bot Destino:", sinal['Bot_Responsavel'] ?? "--"),
                _buildInfoRow("Origem:", sinal['Canal_Origem'] ?? "--"),
                _buildInfoRow("Mercado Solicitado:", sinal['Linha_mercado'] ?? "--"),
                _buildInfoRow("Odd Sinal:", sinal['ODD']?.toString() ?? "--"),
                
                if (convertido && aposta != null) ...[
                  const SizedBox(height: 15),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  _buildSectionHeader("DADOS DA APOSTA (MATCH)", Colors.greenAccent),
                  _buildInfoRow("Bot Executor:", aposta['bot_origem'] ?? "--"),
                  _buildInfoRow("Horário Entrada:", aposta['Data_Horario_Original'] ?? aposta['horario'] ?? "--"),
                  _buildInfoRow("Mercado Entrado:", aposta['Linha_mercado'] ?? aposta['mercado'] ?? "--"),
                  _buildInfoRow("Odd Pegada:", aposta['ODD']?.toString() ?? aposta['odd']?.toString() ?? "--"),
                  _buildInfoRow("Stake:", "R\$ ${aposta['Stake'] ?? aposta['stake'] ?? '--'}"),
                  _buildInfoRow("Resultado:", aposta['Resultado'] ?? aposta['resultado'] ?? "--"),
                ] else ...[
                   const SizedBox(height: 15),
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: Colors.redAccent.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(8)
                     ),
                     child: const Text(
                       "O robô não realizou entrada para este sinal dentro do intervalo de 12 minutos. Possíveis causas: ODD abaixo do limite, Mercado fechado ou Bot Offline.",
                       style: TextStyle(color: Colors.redAccent, fontSize: 11, fontStyle: FontStyle.italic),
                     ),
                   )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110, 
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))
          ),
        ],
      ),
    );
  }
}