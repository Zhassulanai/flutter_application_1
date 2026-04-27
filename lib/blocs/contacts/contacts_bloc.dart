import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/contact.dart';

abstract class ContactsEvent extends Equatable {
  const ContactsEvent();
  @override
  List<Object?> get props => [];
}

class ContactsUpdated extends ContactsEvent {
  final List<Contact> contacts;
  const ContactsUpdated(this.contacts);
  @override
  List<Object?> get props => [contacts];
}

class ContactOnlineChanged extends ContactsEvent {
  final String contactId;
  final bool isOnline;
  const ContactOnlineChanged(this.contactId, this.isOnline);
  @override
  List<Object?> get props => [contactId, isOnline];
}

abstract class ContactsState extends Equatable {
  const ContactsState();
  @override
  List<Object?> get props => [];
}

class ContactsLoaded extends ContactsState {
  final List<Contact> contacts;
  const ContactsLoaded(this.contacts);
  @override
  List<Object?> get props => [contacts];
}

class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  ContactsBloc() : super(const ContactsLoaded([])) {
    on<ContactsUpdated>(_onUpdated);
    on<ContactOnlineChanged>(_onOnlineChanged);
  }

  void _onUpdated(ContactsUpdated event, Emitter<ContactsState> emit) {
    emit(ContactsLoaded(event.contacts));
  }

  void _onOnlineChanged(ContactOnlineChanged event, Emitter<ContactsState> emit) {
    final current = (state as ContactsLoaded).contacts;
    final updated = current.map((c) {
      return c.id == event.contactId ? c.copyWith(isOnline: event.isOnline) : c;
    }).toList();
    emit(ContactsLoaded(updated));
  }
}
