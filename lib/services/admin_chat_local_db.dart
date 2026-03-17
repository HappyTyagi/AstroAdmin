import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/admin_chat_model.dart';

class AdminChatLocalDb {
  static final AdminChatLocalDb _instance = AdminChatLocalDb._internal();
  factory AdminChatLocalDb() => _instance;
  AdminChatLocalDb._internal();

  static const String _databaseName = 'admin_support_chat_cache_v1.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'chat_messages';

  Database? _database;

  Future<Database> _db() async {
    if (_database != null) {
      return _database!;
    }

    final String basePath = await getDatabasesPath();
    final String dbPath = p.join(basePath, _databaseName);
    _database = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: (Database db, int version) async {
        await db.execute('''
CREATE TABLE $_tableName (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  sender_id INTEGER NOT NULL,
  sender_name TEXT NOT NULL,
  sender_role TEXT NOT NULL,
  sender_avatar TEXT,
  message_type TEXT NOT NULL,
  content TEXT NOT NULL,
  media_url TEXT,
  file_name TEXT,
  file_size INTEGER,
  media_duration INTEGER,
  timestamp TEXT NOT NULL,
  is_read INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  UNIQUE(chat_id, message_id) ON CONFLICT REPLACE
)
''');
        await db.execute(
          'CREATE INDEX idx_chat_messages_chat_time ON $_tableName(chat_id, timestamp)',
        );
      },
    );
    return _database!;
  }

  Future<void> upsertMessages(
    String chatId,
    List<AdminMessage> messages,
  ) async {
    if (chatId.trim().isEmpty || messages.isEmpty) {
      return;
    }

    final Database db = await _db();
    final Batch batch = db.batch();
    final int updatedAt = DateTime.now().millisecondsSinceEpoch;

    for (final AdminMessage message in messages) {
      batch.insert(_tableName, <String, Object?>{
        'chat_id': chatId,
        'message_id': message.id,
        'sender_id': message.senderId,
        'sender_name': message.senderName,
        'sender_role': message.senderRole,
        'sender_avatar': message.senderAvatar,
        'message_type': message.messageType,
        'content': message.content,
        'media_url': message.mediaUrl,
        'file_name': message.fileName,
        'file_size': message.fileSize,
        'media_duration': message.mediaDuration,
        'timestamp': message.timestamp.toIso8601String(),
        'is_read': message.isRead ? 1 : 0,
        'updated_at': updatedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<AdminMessage>> getMessages(
    String chatId, {
    int limit = 500,
  }) async {
    if (chatId.trim().isEmpty) {
      return const <AdminMessage>[];
    }

    final Database db = await _db();
    final List<Map<String, Object?>> rows = await db.query(
      _tableName,
      where: 'chat_id = ?',
      whereArgs: <Object?>[chatId],
      orderBy: 'timestamp ASC, id ASC',
      limit: limit,
    );

    return rows.map(_rowToMessage).toList(growable: false);
  }

  AdminMessage _rowToMessage(Map<String, Object?> row) {
    return AdminMessage.fromJson(<String, dynamic>{
      'id': (row['message_id'] ?? '').toString(),
      'chatId': (row['chat_id'] ?? '').toString(),
      'senderId': row['sender_id'] ?? 0,
      'senderName': (row['sender_name'] ?? '').toString(),
      'senderRole': (row['sender_role'] ?? 'user').toString(),
      'senderAvatar': row['sender_avatar'],
      'messageType': (row['message_type'] ?? 'text').toString(),
      'content': (row['content'] ?? '').toString(),
      'mediaUrl': row['media_url'],
      'fileName': row['file_name'],
      'fileSize': row['file_size'],
      'mediaDuration': row['media_duration'],
      'timestamp': (row['timestamp'] ?? '').toString(),
      'isRead': (row['is_read'] ?? 0) == 1,
    });
  }
}
