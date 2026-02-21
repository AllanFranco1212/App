import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class StatusBotWidget extends StatefulWidget {
  final String usuario;
  const StatusBotWidget({super.key, required this.usuario});

  @override
  State<StatusBotWidget> createState() => _StatusBotWidgetState();
}

class _StatusBotWidgetState extends State<StatusBotWidget> {
  late DatabaseReference _statusRef;
  Timer? _timerVerificacao;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _statusRef = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Configuracoes/Status');
    
    // Timer local para forçar atualização da UI a cada 10s (para checar timeout)
    _timerVerificacao = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {}); 
    });
  }

  @override
  void dispose() {
    _timerVerificacao?.cancel();
    super.dispose();
  }

  bool _verificarStatus(int? timestampFirebase) {
    if (timestampFirebase == null) return false;

    // Tempo atual em milissegundos
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Diferença entre Agora e a última vez que o bot deu sinal
    final diff = now - timestampFirebase;

    // Se a diferença for menor que 70 segundos (margem de segurança), está online
    // O Python manda a cada 30s. Se passar de 70s, caiu.
    return diff < 70000; 
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _statusRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
           return _buildBadge(false, "Desconectado");
        }

        final data = snapshot.data!.snapshot.value as Map;
        final int? vistoEm = int.tryParse(data['visto_em']?.toString() ?? '0');
        
        // Aplica a lógica de tempo
        _isOnline = _verificarStatus(vistoEm);
        
        return _buildBadge(_isOnline, _isOnline ? "OPERANTE" : "OFFLINE");
      },
    );
  }

  Widget _buildBadge(bool online, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: online ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: online ? Colors.greenAccent : Colors.redAccent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Efeito de "Pulsar" ou Bolinha simples
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: online ? Colors.greenAccent : Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: online ? Colors.greenAccent.withOpacity(0.6) : Colors.redAccent.withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${widget.usuario.toUpperCase()} ($texto)",
            style: TextStyle(
              color: online ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}