import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class BotDetailsPage extends StatefulWidget {
  final String usuario;
  final String botId;

  const BotDetailsPage({
    super.key, 
    required this.usuario, 
    required this.botId
  });

  @override
  State<BotDetailsPage> createState() => _BotDetailsPageState();
}

class _BotDetailsPageState extends State<BotDetailsPage> {
  final NumberFormat f = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    final refHistorico = FirebaseDatabase.instance.ref(
        'Licencas/${widget.usuario}/Bots_Ativos/${widget.botId}/Historico_de_Apostas');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("Histórico - ${widget.botId.replaceAll('_', ' ')}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: refHistorico.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("Sem histórico recente.", style: TextStyle(color: Colors.white54)));
          }

          final dynamic rawData = snapshot.data!.snapshot.value;
          List<Map<String, dynamic>> apostas = [];

          if (rawData is Map) {
            rawData.forEach((key, value) {
              if (value is Map) {
                // Converte para Map seguro
                final aposta = Map<String, dynamic>.from(value);
                aposta['key_id'] = key;
                apostas.add(aposta);
              }
            });
          }

          // Ordenar por data (recente primeiro)
          apostas.sort((a, b) {
            String dateA = a['Data_Horario_Original'] ?? "";
            String dateB = b['Data_Horario_Original'] ?? "";
            return dateB.compareTo(dateA); 
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: apostas.length,
            itemBuilder: (context, index) {
              return _buildHistoryCard(apostas[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> aposta) {
    String resultado = (aposta['Resultado'] ?? "").toString().toUpperCase();
    bool isGreen = resultado.contains("GREEN");
    bool isRed = resultado.contains("RED");
    
    Color resColor = isGreen ? Colors.greenAccent : (isRed ? Colors.redAccent : Colors.grey);
    
    // Tratamento seguro de valores numéricos
    double stake = _parseMoney(aposta['Stake'] ?? aposta['stake']);
    double odd = _parseMoney(aposta['ODD'] ?? aposta['odd']);
    
    // LÓGICA DE RETORNO SOLICITADA
    double valorRetorno;
    if (isGreen) {
      valorRetorno = stake * odd; // Retorno total positivo
    } else if (isRed) {
      valorRetorno = -stake; // Stake negativa
    } else {
      valorRetorno = 0.0;
    }

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white38,
        leading: Icon(Icons.sports_soccer, color: resColor, size: 28),
        title: Text(
          aposta['Partida'] ?? "Partida Desconhecida",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRowInfo("Horário:", aposta['Data_Horario_Original'] ?? "--"),
                const SizedBox(height: 6),
                _buildRowInfo("Mercado:", aposta['Linha_mercado'] ?? "--"),
                const SizedBox(height: 6),
                _buildRowInfo("ODD:", odd.toStringAsFixed(2)),
                
                // --- NOVAS INFORMAÇÕES (ABAIXO DA ODD) ---
                const SizedBox(height: 6),
                _buildRowInfo("Stake:", f.format(stake)),
                
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text("Retorno: ", style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text(
                      f.format(valorRetorno), // Exibe R$ -10,00 ou R$ 19,50
                      style: TextStyle(
                        color: valorRetorno >= 0 ? Colors.greenAccent : Colors.redAccent, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 13
                      ),
                    ),
                  ],
                ),
                // ------------------------------------------

                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text("Resultado: ", style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text(resultado, style: TextStyle(color: resColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRowInfo(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  double _parseMoney(dynamic v) {
    if (v == null) return 0.0;
    String s = v.toString().replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0.0;
  }
}