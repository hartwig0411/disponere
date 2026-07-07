import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/daily_info.dart';
import '../models/ink_data.dart';
import '../models/journal_entry.dart';

/// Persistenz-Schicht für Journal-Einträge auf Basis von SQLite.
///
/// Löst `shared_preferences` als Speicher ab (Session 14). Das Schema ist
/// bewusst normalisiert, damit Einträge **nach Datum, Tag und Zeitraum
/// abfragbar** sind (Anforderung v3.0; Grundlage u.a. für die Perlenkette):
///
/// - `entries`     — ein Eintrag pro Zeile (Text ODER Tinte als JSON-Blob).
/// - `entry_tags`  — ein Tag pro Zeile, mit lowercase-`tag_key` für
///                   case-insensitive Abfragen und `ord` für stabile
///                   Anzeige-Reihenfolge.
/// - `daily_info`  — Tagesinfos (Session 15). Zeitspanne als `yyyy-MM-dd`
///                   in `start_date`/`end_date`; `end_date` NULL = Einzeltag.
///
/// Das Tag-Register bleibt davon unberührt: Es wird weiter zur Laufzeit aus
/// den Einträgen abgeleitet (keine eigene Persistenz). `entry_tags` ist nur
/// die zusätzliche, abfragbare Projektion.
class JournalRepository {
  static const _dbName = 'disponere.db';

  /// Schema-Version. v2 (Session 15) ergänzt `daily_info` via [_onUpgrade].
  static const _dbVersion = 2;

  /// Alt-Schlüssel der bisherigen shared_preferences-Persistenz.
  static const _prefsEntriesKey = 'entries';

  /// Merker, dass der Einmal-Import bereits gelaufen ist. Verhindert, dass
  /// später gelöschte Einträge aus dem Prefs-Backup wieder auftauchen.
  static const _prefsMigratedKey = 'migrated_to_sqlite';

  Database? _db;

  Future<Database> _database() async {
    final existing = _db;
    if (existing != null) return existing;
    final path = p.join(await getDatabasesPath(), _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Für ON DELETE CASCADE (entry_tags folgt entries).
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _db = db;
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE entries (
        id        TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        content   TEXT NOT NULL,
        ink       TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_entries_timestamp ON entries(timestamp)',
    );
    await db.execute('''
      CREATE TABLE entry_tags (
        entry_id TEXT    NOT NULL,
        tag      TEXT    NOT NULL,
        tag_key  TEXT    NOT NULL,
        ord      INTEGER NOT NULL,
        PRIMARY KEY (entry_id, tag_key),
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_entry_tags_tag_key ON entry_tags(tag_key)',
    );
    // Frische Installation: gleich mit dem aktuellen Schema anlegen.
    await _createDailyInfoTable(db);
  }

  /// Schema-Migrationen. Jede Stufe ist idempotent gedacht und baut auf der
  /// vorherigen auf (kein `else` — bei einem Sprung v1→v3 laufen alle Stufen).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDailyInfoTable(db);
    }
  }

  /// Legt die `daily_info`-Tabelle an (genutzt von [_onCreate] und
  /// [_onUpgrade], damit Neuinstallation und Migration dasselbe Schema teilen).
  Future<void> _createDailyInfoTable(Database db) async {
    await db.execute('''
      CREATE TABLE daily_info (
        id         TEXT PRIMARY KEY,
        text       TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date   TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_daily_info_start ON daily_info(start_date)',
    );
  }

  // ---------------------------------------------------------------------------
  // Lesen — Einträge
  // ---------------------------------------------------------------------------

  /// Alle Einträge, neueste zuerst. Tags werden mitgeladen; ihre Reihenfolge
  /// bleibt über `ord` stabil (ISO8601-Zeitstempel sortiert lexikographisch =
  /// chronologisch).
  Future<List<JournalEntry>> loadAll() async {
    final db = await _database();
    final entryRows = await db.query('entries', orderBy: 'timestamp DESC');
    final tagRows = await db.query('entry_tags', orderBy: 'ord ASC');

    final tagsByEntry = <String, List<String>>{};
    for (final row in tagRows) {
      final id = row['entry_id'] as String;
      (tagsByEntry[id] ??= <String>[]).add(row['tag'] as String);
    }

    return entryRows.map((row) {
      final id = row['id'] as String;
      final inkJson = row['ink'] as String?;
      return JournalEntry(
        id: id,
        timestamp: DateTime.parse(row['timestamp'] as String),
        content: row['content'] as String,
        tags: tagsByEntry[id] ?? const <String>[],
        ink: inkJson != null
            ? InkData.fromJson(jsonDecode(inkJson) as Map<String, dynamic>)
            : null,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Schreiben — Einträge
  // ---------------------------------------------------------------------------

  /// Legt einen Eintrag an oder aktualisiert ihn (inkl. Tags), transaktional.
  Future<void> upsert(JournalEntry entry) async {
    final db = await _database();
    await db.transaction((txn) => _upsertInTxn(txn, entry));
  }

  /// Wie [upsert], aber für mehrere Einträge in einer Transaktion
  /// (z.B. Tag-Umbenennung über alle betroffenen Einträge).
  Future<void> upsertAll(Iterable<JournalEntry> entries) async {
    final db = await _database();
    await db.transaction((txn) async {
      for (final entry in entries) {
        await _upsertInTxn(txn, entry);
      }
    });
  }

  Future<void> _upsertInTxn(Transaction txn, JournalEntry entry) async {
    await txn.insert(
      'entries',
      {
        'id': entry.id,
        'timestamp': entry.timestamp.toIso8601String(),
        'content': entry.content,
        'ink': entry.ink != null ? jsonEncode(entry.ink!.toJson()) : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Tags des Eintrags neu setzen: erst löschen, dann in Reihenfolge einfügen.
    await txn
        .delete('entry_tags', where: 'entry_id = ?', whereArgs: [entry.id]);
    for (var i = 0; i < entry.tags.length; i++) {
      final tag = entry.tags[i];
      await txn.insert(
        'entry_tags',
        {
          'entry_id': entry.id,
          'tag': tag,
          'tag_key': tag.toLowerCase(),
          'ord': i,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Löscht einen Eintrag samt seiner Tags (entry_tags via ON DELETE CASCADE).
  /// Noch kein Aufrufer in der UI — Grundlage für späteres Eintrag-Löschen.
  Future<void> delete(String id) async {
    final db = await _database();
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Daily Info (Session 15)
  // ---------------------------------------------------------------------------

  /// Datums-Schlüssel `yyyy-MM-dd` (lexikographisch = chronologisch sortierbar,
  /// direkt in Bereichsabfragen vergleichbar).
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DailyInfo _dailyInfoFromRow(Map<String, Object?> row) {
    final endRaw = row['end_date'] as String?;
    return DailyInfo(
      id: row['id'] as String,
      text: row['text'] as String,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: endRaw != null ? DateTime.parse(endRaw) : null,
    );
  }

  /// Alle Tagesinfos, deren Zeitspanne den gegebenen Tag abdeckt.
  ///
  /// Nutzt genau die Bereichsabfrage, für die das Schema normalisiert wurde:
  /// `start_date <= tag <= COALESCE(end_date, start_date)`.
  Future<List<DailyInfo>> dailyInfosForDay(DateTime day) async {
    final db = await _database();
    final key = _dateKey(day);
    final rows = await db.query(
      'daily_info',
      where: 'start_date <= ? AND COALESCE(end_date, start_date) >= ?',
      whereArgs: [key, key],
      orderBy: 'start_date ASC',
    );
    return rows.map(_dailyInfoFromRow).toList();
  }

  /// Alle Tagesinfos (für spätere Verwaltungsansicht). Sortiert nach Startdatum.
  Future<List<DailyInfo>> loadAllDailyInfos() async {
    final db = await _database();
    final rows = await db.query('daily_info', orderBy: 'start_date ASC');
    return rows.map(_dailyInfoFromRow).toList();
  }

  /// Legt eine Tagesinfo an oder aktualisiert sie.
  Future<void> upsertDailyInfo(DailyInfo info) async {
    final db = await _database();
    await db.insert(
      'daily_info',
      {
        'id': info.id,
        'text': info.text,
        'start_date': _dateKey(info.startDate),
        'end_date': info.endDate != null ? _dateKey(info.endDate!) : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Löscht eine Tagesinfo.
  Future<void> deleteDailyInfo(String id) async {
    final db = await _database();
    await db.delete('daily_info', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Einmal-Migration aus shared_preferences
  // ---------------------------------------------------------------------------

  /// Übernimmt vorhandene Einträge aus der alten shared_preferences-Persistenz
  /// **einmalig** in die SQLite-DB. Läuft nur, solange das Migrations-Flag
  /// nicht gesetzt ist. Der alte Prefs-Key bleibt als **Backup** erhalten
  /// (wird bewusst nicht gelöscht).
  Future<void> migrateFromPrefsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsMigratedKey) ?? false) return;

    final raw = prefs.getStringList(_prefsEntriesKey) ?? const [];
    if (raw.isNotEmpty) {
      final entries = raw.map((s) {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return JournalEntry(
          id: map['id'] as String,
          timestamp: DateTime.parse(map['timestamp'] as String),
          content: map['content'] as String,
          tags: List<String>.from(map['tags'] as List),
          ink: map['ink'] != null
              ? InkData.fromJson(map['ink'] as Map<String, dynamic>)
              : null,
        );
      }).toList();
      await upsertAll(entries);
    }

    // Flag setzen — auch wenn nichts zu übernehmen war (dann bleibt es einfach
    // bei einer leeren DB). Prefs-Backup ('entries') bleibt liegen.
    await prefs.setBool(_prefsMigratedKey, true);
  }
}
