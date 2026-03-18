import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/admin_chat_model.dart';

class AdminChatLocalDb {
  static final AdminChatLocalDb _instance = AdminChatLocalDb._internal();
  factory AdminChatLocalDb() => _instance;
  AdminChatLocalDb._internal();

  static const String _databaseName = 'admin_support_chat_cache_v1.db';
  static const int _databaseVersion = 2;
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
  timestamp_epoch INTEGER NOT NULL,
  is_read INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  UNIQUE(chat_id, message_id) ON CONFLICT REPLACE
)
''');
        await db.execute(
          'CREATE INDEX idx_chat_messages_chat_time ON $_tableName(chat_id, timestamp_epoch)',
        );
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await _migrateToV2(db);
        }
      },
    );
    return _database!;
  }

  Future<void> _migrateToV2(Database db) async {
    final List<Map<String, Object?>> tableInfo = await db.rawQuery(
      'PRAGMA table_info($_tableName)',
    );
    final bool hasTimestampEpoch = tableInfo.any(
      (Map<String, Object?> row) => row['name'] == 'timestamp_epoch',
    );
    if (!hasTimestampEpoch) {
      await db.execute(
        'ALTER TABLE $_tableName ADD COLUMN timestamp_epoch INTEGER NOT NULL DEFAULT 0',
      );
    }
    await db.execute('''
UPDATE $_tableName
SET timestamp_epoch = CASE
  WHEN timestamp_epoch > 0 THEN timestamp_epoch
  ELSE COALESCE(
    CAST(strftime('%s', replace(substr(timestamp, 1, 19), 'T', ' ')) AS INTEGER) * 1000,
    updated_at
  )
END
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_time ON $_tableName(chat_id, timestamp_epoch)',
    );
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
      final String normalizedMessageId = _normalizeMessageId(message);
      batch.insert(_tableName, <String, Object?>{
        'chat_id': chatId,
        'message_id': normalizedMessageId,
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
        'timestamp_epoch': message.timestamp.millisecondsSinceEpoch,
        'is_read': message.isRead ? 1 : 0,
        'updated_at': updatedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<AdminMessage>> getMessages(
    String chatId, {
    int limit = 2000,
  }) async {
    if (chatId.trim().isEmpty) {
      return const <AdminMessage>[];
    }

    final Database db = await _db();
    final List<Map<String, Object?>> rows = await db.query(
      _tableName,
      where: 'chat_id = ?',
      whereArgs: <Object?>[chatId],
      orderBy: 'timestamp_epoch DESC, id DESC',
      limit: limit,
    );
    final List<AdminMessage> list = rows.map(_rowToMessage).toList();
    return list.reversed.toList(growable: false);
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

  String _normalizeMessageId(AdminMessage message) {
    final String raw = message.id.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    final int contentHash = message.content.hashCode.abs();
    return 'local_${message.senderRole}_${message.senderId}_${message.timestamp.millisecondsSinceEpoch}_$contentHash';
  }
}
