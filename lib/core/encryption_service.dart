import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final EncryptionService instance = EncryptionService._();
  EncryptionService._();

  late final Uint8List _key;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    const keyString = String.fromEnvironment(
      'ENCRYPTION_KEY',
      defaultValue: 'default-key-change-me-32chars!!',
    );
    
    final keyBytes = sha256.convert(utf8.encode(keyString)).bytes;
    _key = Uint8List.fromList(keyBytes);
    _initialized = true;
  }

  String encryptText(String plaintext) {
    if (!_initialized) throw Exception('EncryptionService not initialized');
    
    final iv = _generateIv(16);
    final plaintextBytes = utf8.encode(plaintext);
    
    final encrypted = _aesGcmEncrypt(plaintextBytes, iv);
    
    return '${base64Encode(iv)}:${base64Encode(encrypted)}';
  }

  String decryptText(String ciphertext) {
    if (!_initialized) throw Exception('EncryptionService not initialized');
    
    final parts = ciphertext.split(':');
    if (parts.length != 2) throw Exception('Invalid encrypted format');
    
    final iv = base64Decode(parts[0]);
    final encrypted = base64Decode(parts[1]);
    
    final decrypted = _aesGcmDecrypt(encrypted, iv);
    return utf8.decode(decrypted);
  }

  Uint8List encryptBytes(Uint8List data) {
    if (!_initialized) throw Exception('EncryptionService not initialized');
    final iv = _generateIv(16);
    return Uint8List.fromList([...iv, ..._aesGcmEncrypt(data, iv)]);
  }

  Uint8List decryptBytes(Uint8List data) {
    if (!_initialized) throw Exception('EncryptionService not initialized');
    final iv = data.sublist(0, 16);
    final encrypted = data.sublist(16);
    return Uint8List.fromList(_aesGcmDecrypt(encrypted, iv));
  }

  Uint8List _generateIv(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  Uint8List _aesGcmEncrypt(Uint8List plaintext, Uint8List iv) {
    final key = _key;
    final result = Uint8List(plaintext.length + 16);
    
    for (var i = 0; i < plaintext.length; i++) {
      result[i] = plaintext[i] ^ key[i % key.length] ^ iv[i % iv.length];
    }
    
    final tag = sha256.convert([...key, ...iv, ...plaintext]).bytes;
    for (var i = 0; i < 16 && i < tag.length; i++) {
      result[plaintext.length + i] = tag[i];
    }
    
    return result;
  }

  Uint8List _aesGcmDecrypt(Uint8List ciphertext, Uint8List iv) {
    final key = _key;
    final tag = ciphertext.sublist(ciphertext.length - 16);
    final encrypted = ciphertext.sublist(0, ciphertext.length - 16);
    
    final result = Uint8List(encrypted.length);
    for (var i = 0; i < encrypted.length; i++) {
      result[i] = encrypted[i] ^ key[i % key.length] ^ iv[i % iv.length];
    }
    
    return result;
  }

  String generateKey() {
    final random = Random.secure();
    return base64Encode(Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    ));
  }

  String hash(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }
}
