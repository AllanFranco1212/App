import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'balance_card.dart';

class BalanceStreamWidget extends StatelessWidget {
  const BalanceStreamWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref('Conta');

    return StreamBuilder(
      stream: dbRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return const BalanceCard(saldo: "Erro", ultimaSinc: "--:--:--");
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BalanceCard(saldo: "Carregando...", ultimaSinc: "Sincronizando...");
        }

        final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
        
        if (data == null) {
          return const BalanceCard(saldo: "R\$ 0,00", ultimaSinc: "--:--:--");
        }

        // Extraindo os dois valores do seu print do Firebase
        final String saldoReal = data['saldo_atual']?.toString() ?? "R\$ 0,00";
        final String sincReal = data['ultima_sincronizacao']?.toString() ?? "--:--:--";

        return BalanceCard(
          saldo: saldoReal, 
          ultimaSinc: sincReal, // Enviando a hora para o visual
        );
      },
    );
  }
}