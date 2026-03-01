import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Importações dos seus arquivos
import 'widgets/menu_option_item.dart';
import 'widgets/status_widget.dart';
import 'telas/history_page.dart';
import 'telas/config_page.dart';
import 'telas/preferences_page.dart';
import 'telas/login_page.dart';
import 'telas/license_page.dart';
import 'telas/analytics_page.dart';

// Configuração Global de Notificações
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização do Firebase
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSy... (SUA KEY)", 
        appId: "1:1060352114666:android:...", 
        messagingSenderId: "1060352114666",
        projectId: "autobet-e3631",
        databaseURL: "https://autobet-e3631-default-rtdb.firebaseio.com/",
      ),
    );
  } catch (e) {
    debugPrint("Erro Firebase: $e");
  }

  // Inicialização das Notificações Locais (Android + iOS)
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      
  // NOVO: Configuração obrigatória para o motor do iPhone
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  // ATUALIZADO: Agrupando as regras de Android e iOS
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS, 
  );
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const BetAutomationApp());
}

class BetAutomationApp extends StatefulWidget {
  const BetAutomationApp({super.key});

  @override
  State<BetAutomationApp> createState() => _BetAutomationAppState();
}

class _BetAutomationAppState extends State<BetAutomationApp> {
  bool _estaLogado = false; 
  String _usuarioAtual = "";
  bool _verificandoLogin = true;

  @override
  void initState() {
    super.initState();
    _verificarLoginSalvo();
  }

  // --- LÓGICA DE LOGIN PERSISTENTE ---
  Future<void> _verificarLoginSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioSalvo = prefs.getString('usuario_logado');
    
    if (usuarioSalvo != null && usuarioSalvo.isNotEmpty) {
      setState(() {
        _usuarioAtual = usuarioSalvo;
        _estaLogado = true;
      });
    }
    setState(() => _verificandoLogin = false);
  }

  Future<void> _autorizarAcesso(String usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuario_logado', usuario); // Salva no disco

    setState(() {
      _estaLogado = true;
      _usuarioAtual = usuario;
    });
  }

  Future<void> _bloquearAcesso() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_logado'); // Remove do disco

    setState(() {
      _estaLogado = false;
      _usuarioAtual = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoLogin) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: _estaLogado 
          // Envolvemos a Dashboard com o Gerenciador de Notificações
          ? LogNotificationManager(
              usuario: _usuarioAtual,
              child: DashboardPage(onLogout: _bloquearAcesso, usuario: _usuarioAtual),
            )
          : LoginPage(onLoginSuccess: _autorizarAcesso),
    );
  }
}

// --- NOVO WIDGET: Gerenciador de Notificações em Background (Log Monitor) ---
class LogNotificationManager extends StatefulWidget {
  final String usuario;
  final Widget child;

  const LogNotificationManager({super.key, required this.usuario, required this.child});

  @override
  State<LogNotificationManager> createState() => _LogNotificationManagerState();
}

class _LogNotificationManagerState extends State<LogNotificationManager> {
  final Map<String, StreamSubscription> _logSubscriptions = {};
  late DatabaseReference _botsRef;
  late int _appStartTime;

  @override
  void initState() {
    super.initState();
    _appStartTime = DateTime.now().millisecondsSinceEpoch;
    _botsRef = FirebaseDatabase.instance.ref('Licencas/${widget.usuario}/Bots_Ativos');
    _iniciarMonitoramento();
  }

  void _iniciarMonitoramento() {
    // Escuta a lista de bots para adicionar listeners dinamicamente
    _botsRef.onValue.listen((event) {
      if (event.snapshot.value == null) return;
      
      final data = event.snapshot.value;
      if (data is Map) {
        final currentBotKeys = data.keys.map((e) => e.toString()).toSet();

        // 1. Adiciona listeners para novos bots
        for (var botId in currentBotKeys) {
          if (!_logSubscriptions.containsKey(botId)) {
            _adicionarListenerLog(botId);
          }
        }

        // 2. Remove listeners de bots excluídos
        _logSubscriptions.removeWhere((botId, sub) {
          if (!currentBotKeys.contains(botId)) {
            sub.cancel();
            return true;
          }
          return false;
        });
      }
    });
  }

  void _adicionarListenerLog(String botId) {
    // Monitora a pasta "Logs" de cada bot
    // startAt(_appStartTime) garante que só notifica logs NOVOS criados após abrir o app
    final logsRef = _botsRef.child(botId).child('Logs')
        .orderByChild('timestamp')
        .startAt(_appStartTime.toDouble());

    final sub = logsRef.onChildAdded.listen((event) {
      final logData = event.snapshot.value as Map?;
      if (logData != null) {
        final mensagem = logData['mensagem']?.toString() ?? "";
        final nivel = logData['nivel']?.toString() ?? "INFO";

        // Filtro da Notificação solicitado: "##NOTIFICACAO##"
        if (mensagem.contains("##NOTIFICACAO##")) {
        // Limpa a tag para exibir bonito
        final msgLimpa = mensagem.replaceAll("##NOTIFICACAO##", "").trim();
        
        // DISPARA O ALERTA NO CELULAR
        _mostrarNotificacaoLocal(
          titulo: "Alerta do $botId ($nivel)", 
          corpo: msgLimpa // Aqui vai aparecer: "ALERTA [Bot_1]: Verificação Facial Solicitada..."
        );
      }
      }
    });

    _logSubscriptions[botId] = sub;
  }

  Future<void> _mostrarNotificacaoLocal({required String titulo, required String corpo}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'channel_alerts', 'Alertas de Segurança',
      channelDescription: 'Notificações críticas dos bots',
      importance: Importance.max,
      priority: Priority.high,
      color: Colors.redAccent,
      styleInformation: BigTextStyleInformation(''), // Permite texto longo
    );
    
    // NOVO: Detalhes visuais da notificação no iPhone
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    // ATUALIZADO: Juntando Android e iOS
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails, // Inserido aqui!
    );
    
    // ID único baseado no tempo para não sobrescrever
    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      titulo,
      corpo,
      details,
    );
  }

  @override
  void dispose() {
    for (var sub in _logSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// --- Fim do Gerenciador ---

class DashboardPage extends StatelessWidget {
  final VoidCallback onLogout;
  final String usuario; 

  const DashboardPage({
    super.key, 
    required this.onLogout, 
    required this.usuario
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bet Bot Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: onLogout,
            tooltip: "Sair",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AnalyticsPage(usuario: usuario)),
                );
              },
              child: SaldoSomadoWidget(usuario: usuario),
            ),

            const SizedBox(height: 12),
            
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBotWidget(usuario: usuario),
            ),

            const SizedBox(height: 32),
            const Text(
              "Configurações e Controle",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),

            MenuOptionItem(
              icon: Icons.storage_rounded,
              title: "Dados da Licença",
              subtitle: "API Telegram e Chaves",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserLicensePage(usuario: usuario))),
            ),

            MenuOptionItem(
              icon: Icons.android_rounded,
              title: "Configuração de Bots",
              subtitle: "Credenciais e Regras",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ConfigPage(usuario: usuario))),
            ),

            MenuOptionItem(
              icon: Icons.analytics_outlined,
              title: "Estatísticas Detalhadas",
              subtitle: "ROI, Assertividade e Eficiência",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyticsPage(usuario: usuario))),
            ),

            MenuOptionItem(
              icon: Icons.history_rounded,
              title: "Performance dos Bots",
              subtitle: "Histórico de Resultados",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HistoryPage(usuario: usuario))),
            ),

            MenuOptionItem(
              icon: Icons.tune_rounded,
              title: "Preferências",
              subtitle: "Ajustes de Sistema",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PreferencesPage(usuario: usuario))),
            ),
          ],
        ),
      ),
    );
  }
}

class SaldoSomadoWidget extends StatelessWidget {
  final String usuario;
  const SaldoSomadoWidget({super.key, required this.usuario});

  double _converterSaldo(dynamic valor) {
    if (valor == null) return 0.0;
    String str = valor.toString();
    str = str.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (str.contains(',')) {
      str = str.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(str) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final botsRef = FirebaseDatabase.instance.ref('Licencas/$usuario/Bots_Ativos');
    
    return StreamBuilder(
      stream: botsRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        double total = 0.0;
        
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final dynamic rawData = snapshot.data!.snapshot.value;
          
          if (rawData is Map) {
             rawData.forEach((key, value) {
              if (value is Map) {
                total += _converterSaldo(value['Conta']?['saldo_atual']);
              }
            });
          }
        }
        
        final f = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("SALDO TOTAL", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.5), size: 14),
                ],
              ),
              const SizedBox(height: 8),
              Text(f.format(total).replaceFirst('R\$', 'R\$ '), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Clique para ver relatórios de eficiência", style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }
}
