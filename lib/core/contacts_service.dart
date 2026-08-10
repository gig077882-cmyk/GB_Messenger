import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';

class PhoneContact {
  final String name;
  final String phone;
  final String? avatarUrl;
  final bool registered;

  const PhoneContact({
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.registered = false,
  });
}

class ContactsService {
  static final ContactsService instance = ContactsService._();
  ContactsService._();

  final ApiService _api = ApiService.instance;

  Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  Future<List<PhoneContact>> getPhoneContacts() async {
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) return [];
    }
    final contacts = await FlutterContacts.getAll();
    final result = <PhoneContact>[];
    for (final c in contacts) {
      if (c.phones.isEmpty) continue;
      for (final phone in c.phones) {
        final num = phone.number;
        if (num.isEmpty) continue;
        final normalized = normalizePhone(num);
        if (normalized.length >= 10) {
          result.add(
            PhoneContact(
              name: (c.displayName?.isNotEmpty == true) ? c.displayName! : num,
              phone: normalized,
            ),
          );
        }
      }
    }
    return result;
  }

  String normalizePhone(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('8') && cleaned.length == 11) {
      cleaned = '+7${cleaned.substring(1)}';
    } else if (cleaned.startsWith('7') && cleaned.length == 11) {
      cleaned = '+$cleaned';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  Future<List<PhoneContact>> syncContacts() async {
    final phoneContacts = await getPhoneContacts();
    if (phoneContacts.isEmpty) return [];
    final phones = phoneContacts.map((c) => c.phone).toList();
    try {
      final registered = await _api.syncContacts(phones);
      final registeredIds = registered.map((u) => u.phone).toSet();
      return phoneContacts
          .map(
            (c) => PhoneContact(
              name: c.name,
              phone: c.phone,
              registered: registeredIds.contains(c.phone),
            ),
          )
          .toList();
    } catch (_) {
      return phoneContacts;
    }
  }
}
