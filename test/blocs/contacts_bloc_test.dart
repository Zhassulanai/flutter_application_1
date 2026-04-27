import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/blocs/contacts/contacts_bloc.dart';
import 'package:flutter_application_1/data/models/contact.dart';

void main() {
  test('initial state is empty', () {
    final bloc = ContactsBloc();
    expect(bloc.state, isA<ContactsLoaded>());
    expect((bloc.state as ContactsLoaded).contacts, isEmpty);
    bloc.close();
  });

  test('ContactsUpdated replaces contact list', () async {
    final bloc = ContactsBloc();
    final contact = Contact(
      id: 'id-1', name: 'Мама', ipAddress: '192.168.1.5',
      port: 8765, isOnline: true, lastSeen: 0,
    );
    bloc.add(ContactsUpdated([contact]));
    await Future.delayed(Duration.zero);
    final state = bloc.state as ContactsLoaded;
    expect(state.contacts.length, equals(1));
    expect(state.contacts.first.name, equals('Мама'));
    bloc.close();
  });
}
