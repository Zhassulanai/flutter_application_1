import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/contacts/contacts_bloc.dart';
import 'blocs/network/network_bloc.dart';
import 'data/database.dart';
import 'data/repositories/contact_repository.dart';
import 'network/connection_pool.dart';
import 'network/mdns_service.dart';
import 'network/websocket_server.dart';
import 'services/identity_service.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/chat_list_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _networkBloc = NetworkBloc();
  final _contactsBloc = ContactsBloc();
  final _server = WebSocketServer();
  final _pool = ConnectionPool();
  final _mdns = MdnsService();

  @override
  void initState() {
    super.initState();
    _startNetwork();
  }

  Future<void> _startNetwork() async {
    await _server.start();
    _server.onMessage = _onRawMessage;
    _pool.onDisconnected = (peerId) {
      _networkBloc.add(PeerDisconnected(peerId));
      _contactsBloc.add(ContactOnlineChanged(peerId, false));
      ContactRepository(AppDatabase.instance).setOnline(peerId, false);
    };
    _mdns.onPeerFound = (peer) async {
      final self = IdentityService.instance.ownId;
      if (peer.id == self) return;
      await ContactRepository(AppDatabase.instance).updateAddress(peer.id, peer.ip, peer.port);
      await ContactRepository(AppDatabase.instance).setOnline(peer.id, true);
      await _pool.connect(peer.id, peer.ip, peer.port);
      _networkBloc.add(PeerConnected(peer.id));
      _contactsBloc.add(ContactOnlineChanged(peer.id, true));
      _loadContacts();
    };
    await _mdns.startScan();
    _networkBloc.add(NetworkStarted());
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await ContactRepository(AppDatabase.instance).getAll();
    _contactsBloc.add(ContactsUpdated(contacts));
  }

  void _onRawMessage(String raw, dynamic _) {
    _networkBloc.add(MessageReceived('', raw));
  }

  @override
  void dispose() {
    _mdns.stopScan();
    _server.stop();
    _pool.closeAll();
    _networkBloc.close();
    _contactsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _networkBloc),
        BlocProvider.value(value: _contactsBloc),
      ],
      child: MaterialApp(
        title: 'FamilyChat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25D366)),
          useMaterial3: true,
        ),
        home: FutureBuilder<bool>(
          future: IdentityService.instance.isOnboarded(),
          builder: (context, snap) {
            if (snap.hasError) return Scaffold(body: Center(child: Text('Ошибка инициализации: ${snap.error}')));
            if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            return snap.data! ? const ChatListScreen() : const OnboardingScreen();
          },
        ),
      ),
    );
  }
}
