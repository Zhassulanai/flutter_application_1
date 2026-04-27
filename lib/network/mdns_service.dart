import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

const _serviceType = '_familychat._tcp';

class DiscoveredPeer {
  final String id;
  final String ip;
  final int port;
  final String name;
  const DiscoveredPeer({required this.id, required this.ip, required this.port, required this.name});
}

class MdnsService {
  final MDnsClient _client = MDnsClient();
  final _discovered = <String, DiscoveredPeer>{};
  Timer? _scanTimer;

  void Function(DiscoveredPeer peer)? onPeerFound;
  void Function(String peerId)? onPeerLost;

  Future<void> register({
    required String ownId,
    required String name,
    required int port,
  }) async {
    // mDNS registration is handled by platform-native code (Task 15).
    // Service name encodes our UUID for peer identification on discovery.
  }

  Future<void> startScan() async {
    await _client.start();
    _scanTimer = Timer.periodic(const Duration(seconds: 10), (_) => _scan());
    await _scan();
  }

  Future<void> _scan() async {
    await for (final ptr in _client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(_serviceType),
    )) {
      await for (final srv in _client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      )) {
        await for (final ip in _client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        )) {
          final parts = ptr.domainName.split('.');
          if (parts.isEmpty) continue;
          final peerId = parts.first;
          final peer = DiscoveredPeer(
            id: peerId,
            ip: ip.address.address,
            port: srv.port,
            name: peerId,
          );
          if (!_discovered.containsKey(peerId)) {
            _discovered[peerId] = peer;
            onPeerFound?.call(peer);
          }
        }
      }
    }
  }

  void stopScan() {
    _scanTimer?.cancel();
    _client.stop();
  }
}
