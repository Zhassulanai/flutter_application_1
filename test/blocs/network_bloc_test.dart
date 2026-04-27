import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_application_1/blocs/network/network_bloc.dart';

void main() {
  group('NetworkBloc', () {
    test('initial state is disconnected', () {
      final bloc = NetworkBloc();
      expect(bloc.state, isA<NetworkDisconnected>());
      bloc.close();
    });
  });
}
