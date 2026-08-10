import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../../features/chat/models/local_message.dart';

/// Локальная SQLite-БД: кэш сообщений, pending-очередь при офлайне.
class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._();
  LocalDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'gb_messenger.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            type TEXT NOT NULL,
            text TEXT,
            media_key TEXT,
            media_url TEXT,
            media_meta TEXT,
            reply_to_id TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            statuses TEXT NOT NULL DEFAULT '[]'
          )''');
        await db.execute(
          'CREATE INDEX idx_messages_chat ON messages(chat_id, created_at)',
        );
        await db.execute('''
          CREATE TABLE pending_messages (
            local_id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            type TEXT NOT NULL,
            text TEXT,
            media_key TEXT,
            media_url TEXT,
            media_meta TEXT,
            reply_to_id TEXT,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )''');
        await db.execute('''
          CREATE TABLE chats_meta (
            chat_id TEXT PRIMARY KEY,
            last_message_at TEXT,
            unread_count INTEGER NOT NULL DEFAULT 0,
            last_sync_at TEXT
          )''');
      },
    );
  }

  /// Вставка/обновление сообщений (из сервера или пуша).
  Future<void> upsertMessages(List<LocalMessage> messages) async {
    final db = await this.db;
    final batch = db.batch();
    for (final m in messages) {
      batch.insert(
        'messages',
        m.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<LocalMessage>> messagesForChat(
    String chatId, {
    int limit = 50,
    String? before,
  }) async {
    final db = await this.db;
    final rows = await db.query(
      'messages',
      where: before != null ? 'chat_id = ? AND created_at < ?' : 'chat_id = ?',
      whereArgs: before != null ? [chatId, before] : [chatId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    final list = rows.map(LocalMessage.fromRow).toList();
    return list.reversed.toList();
  }

  Future<void> deleteMessage(String id) async {
    final db = await this.db;
    await db.update(
      'messages',
      {'is_deleted': 1, 'text': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<LocalMessage?> findMessageById(String id) async {
    final db = await this.db;
    final rows = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocalMessage.fromRow(rows.first);
  }

  // ── Pending (offline) queue ───────────────────────────────────────────
  Future<void> enqueuePending(LocalMessage m) async {
    final db = await this.db;
    final row = m.toRow();
    row['local_id'] = row.remove('id');
    await db.insert(
      'pending_messages',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocalMessage>> pendingMessages() async {
    final db = await this.db;
    final rows = await db.query('pending_messages', orderBy: 'created_at ASC');
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      map['id'] = map.remove('local_id');
      return LocalMessage.fromRow(map);
    }).toList();
  }

  Future<void> markPendingSent(String localId, String serverId) async {
    final db = await this.db;
    await db.delete(
      'pending_messages',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> incrementPendingAttempt(String localId, String error) async {
    final db = await this.db;
    await db.rawUpdate(
      'UPDATE pending_messages SET attempts = attempts + 1, last_error = ? WHERE local_id = ?',
      [error, localId],
    );
  }

  Future<void> prunePendingOlderThan(Duration age) async {
    final db = await this.db;
    final cutoff = DateTime.now().subtract(age).toIso8601String();
    await db.delete(
      'pending_messages',
      where: 'created_at < ? AND attempts >= 5',
      whereArgs: [cutoff],
    );
  }

  // ── Chat meta ─────────────────────────────────────────────────────────
  Future<void> updateChatMeta(
    String chatId,
    DateTime lastMessageAt,
    int unreadDelta,
  ) async {
    final db = await this.db;
    final existing = await db.query(
      'chats_meta',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
    if (existing.isEmpty) {
      await db.insert('chats_meta', {
        'chat_id': chatId,
        'last_message_at': lastMessageAt.toIso8601String(),
        'unread_count': unreadDelta.clamp(0, 9999),
        'last_sync_at': DateTime.now().toIso8601String(),
      });
    } else {
      final cur = existing.first;
      final newUnread = ((cur['unread_count'] as int?) ?? 0) + unreadDelta;
      await db.update(
        'chats_meta',
        {
          'last_message_at': lastMessageAt.toIso8601String(),
          'unread_count': newUnread.clamp(0, 9999),
          'last_sync_at': DateTime.now().toIso8601String(),
        },
        where: 'chat_id = ?',
        whereArgs: [chatId],
      );
    }
  }
}
