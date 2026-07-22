import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/calendar_event.dart';
import '../models/calendar_source.dart';
import '../models/daily_info.dart';
import '../models/ink_data.dart';
import '../models/journal_entry.dart';
import '../models/task.dart';

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
/// - `tasks`       — Aufgaben (Session 16). Fälligkeits-Day als `yyyy-MM-dd`
///                   in `due_day` (NULL = ohne Day), Uhrzeit als `HH:mm` in
///                   `due_time`, `done` als 0/1.
/// - `task_tags`   — ein Tag pro Aufgabe und Zeile, analog `entry_tags`.
///                   Macht Aufgaben **nach Tag abfragbar** (`tasksForTag`) —
///                   Grundlage für die „alles zu einem Tag"-Ansicht.
/// - `calendar_sources` / `calendar_source_tags` — die ausgewählten Google-
///                   Kalender und ihre Tag-Zuordnung (Session 20).
/// - `calendar_events` / `event_tags` — die gespiegelten Termine (Session 21).
///                   Zeitspanne als `yyyy-MM-dd` in `start_day`/`end_day`
///                   (Endtag **inklusiv**), Uhrzeit als `HH:mm` in lokaler
///                   Zeit. `event_tags` materialisiert die vom Kalender
///                   geerbten Tags, damit Termine in derselben Form nach Tag
///                   abfragbar sind wie Einträge und Aufgaben.
///
/// Das Tag-Register bleibt davon unberührt: Es wird weiter zur Laufzeit aus
/// den Einträgen abgeleitet (keine eigene Persistenz). `entry_tags` und
/// `task_tags` sind nur die zusätzlichen, abfragbaren Projektionen.
class JournalRepository {
  static const _dbName = 'disponere.db';

  /// Schema-Version. v2 (Session 15) ergänzt `daily_info`, v3 (Session 16)
  /// ergänzt `tasks` + `task_tags`, v4 (Session 20) ergänzt `calendar_sources`
  /// + `calendar_source_tags`; v5 ergänzt `calendar_events` + `event_tags` —
  /// jeweils via [_onUpgrade].
  static const _dbVersion = 5;

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
    await _createTaskTables(db);
    await _createCalendarSourceTables(db);
    await _createCalendarEventTables(db);
  }

  /// Schema-Migrationen. Jede Stufe ist idempotent gedacht und baut auf der
  /// vorherigen auf (kein `else` — bei einem Sprung v1→v3 laufen alle Stufen).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createDailyInfoTable(db);
    }
    if (oldVersion < 3) {
      await _createTaskTables(db);
    }
    if (oldVersion < 4) {
      await _createCalendarSourceTables(db);
    }
    if (oldVersion < 5) {
      await _createCalendarEventTables(db);
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

  /// Legt `tasks` + `task_tags` an (genutzt von [_onCreate] und [_onUpgrade],
  /// damit Neuinstallation und Migration dasselbe Schema teilen). `task_tags`
  /// spiegelt `entry_tags` (lowercase `tag_key`, `ord`, ON DELETE CASCADE).
  Future<void> _createTaskTables(Database db) async {
    await db.execute('''
      CREATE TABLE tasks (
        id       TEXT PRIMARY KEY,
        title    TEXT    NOT NULL,
        due_day  TEXT,
        due_time TEXT,
        done     INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_tasks_due_day ON tasks(due_day)',
    );
    await db.execute('''
      CREATE TABLE task_tags (
        task_id TEXT    NOT NULL,
        tag     TEXT    NOT NULL,
        tag_key TEXT    NOT NULL,
        ord     INTEGER NOT NULL,
        PRIMARY KEY (task_id, tag_key),
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_task_tags_tag_key ON task_tags(tag_key)',
    );
  }

  /// Legt `calendar_sources` + `calendar_source_tags` an (genutzt von
  /// [_onCreate] und [_onUpgrade], damit Neuinstallation und Migration
  /// dasselbe Schema teilen). `calendar_source_tags` spiegelt `task_tags`
  /// (lowercase `tag_key`, `ord`, ON DELETE CASCADE). `enabled` ist standardmäßig
  /// 0 — neue Kalender bleiben aus, bis der Nutzer sie aktiviert.
  Future<void> _createCalendarSourceTables(Database db) async {
    await db.execute('''
      CREATE TABLE calendar_sources (
        calendar_id  TEXT PRIMARY KEY,
        display_name TEXT    NOT NULL,
        enabled      INTEGER NOT NULL DEFAULT 0,
        sync_token   TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE calendar_source_tags (
        calendar_id TEXT    NOT NULL,
        tag         TEXT    NOT NULL,
        tag_key     TEXT    NOT NULL,
        ord         INTEGER NOT NULL,
        PRIMARY KEY (calendar_id, tag_key),
        FOREIGN KEY (calendar_id) REFERENCES calendar_sources(calendar_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_calendar_source_tags_tag_key '
      'ON calendar_source_tags(tag_key)',
    );
  }

  /// Legt `calendar_events` + `event_tags` an (genutzt von [_onCreate] und
  /// [_onUpgrade], damit Neuinstallation und Migration dasselbe Schema teilen).
  ///
  /// Der Primärschlüssel ist **zusammengesetzt** (`calendar_id`, `event_id`):
  /// Dieselbe Einladung kann in mehreren aktivierten Kalendern liegen und wäre
  /// über die Event-ID allein nicht eindeutig. `ical_uid` steht für die
  /// spätere Deduplizierung bereit.
  ///
  /// `start_day`/`end_day` sind `yyyy-MM-dd` mit **inklusivem** Endtag —
  /// dieselbe Form wie bei `daily_info`, damit die Tagesabfrage identisch
  /// aussieht.
  Future<void> _createCalendarEventTables(Database db) async {
    await db.execute('''
      CREATE TABLE calendar_events (
        calendar_id TEXT    NOT NULL,
        event_id    TEXT    NOT NULL,
        ical_uid    TEXT,
        summary     TEXT    NOT NULL,
        location    TEXT,
        all_day     INTEGER NOT NULL DEFAULT 0,
        start_day   TEXT    NOT NULL,
        start_time  TEXT,
        end_day     TEXT    NOT NULL,
        end_time    TEXT,
        PRIMARY KEY (calendar_id, event_id),
        FOREIGN KEY (calendar_id) REFERENCES calendar_sources(calendar_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_calendar_events_start ON calendar_events(start_day)',
    );
    await db.execute('''
      CREATE TABLE event_tags (
        calendar_id TEXT    NOT NULL,
        event_id    TEXT    NOT NULL,
        tag         TEXT    NOT NULL,
        tag_key     TEXT    NOT NULL,
        ord         INTEGER NOT NULL,
        PRIMARY KEY (calendar_id, event_id, tag_key),
        FOREIGN KEY (calendar_id, event_id)
          REFERENCES calendar_events(calendar_id, event_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_event_tags_tag_key ON event_tags(tag_key)',
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
  // Aufgaben (Session 16)
  // ---------------------------------------------------------------------------

  /// Baut aus `tasks`-Zeilen [Task]-Objekte inkl. ihrer Tags auf. Lädt die
  /// Tags der betroffenen Aufgaben in **einer** Abfrage nach (Reihenfolge über
  /// `ord` stabil), statt pro Aufgabe einzeln.
  Future<List<Task>> _hydrateTasks(
      Database db, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const [];

    final ids = rows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final tagRows = await db.query(
      'task_tags',
      where: 'task_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'ord ASC',
    );

    final tagsByTask = <String, List<String>>{};
    for (final row in tagRows) {
      final tid = row['task_id'] as String;
      (tagsByTask[tid] ??= <String>[]).add(row['tag'] as String);
    }

    return rows.map((row) {
      final id = row['id'] as String;
      final dueDayRaw = row['due_day'] as String?;
      return Task(
        id: id,
        title: row['title'] as String,
        dueDay: dueDayRaw != null ? DateTime.parse(dueDayRaw) : null,
        dueTime: row['due_time'] as String?,
        done: (row['done'] as int) == 1,
        tags: tagsByTask[id] ?? const <String>[],
      );
    }).toList();
  }

  /// Aufgaben, die am gegebenen Day im Journal erscheinen sollen: alle
  /// **offenen** Aufgaben mit `due_day <= day` (also fällig oder überfällig)
  /// **oder** ganz ohne Day. Zukünftig datierte bleiben weg (analog zum
  /// Daily-Info-Zukunftsfall); erledigte fallen ganz heraus.
  ///
  /// Sortierung: nach Day aufsteigend (überfällige zuerst), danach Uhrzeit;
  /// Aufgaben ohne Day/Uhrzeit jeweils zuletzt.
  Future<List<Task>> surfacedTasksForDay(DateTime day) async {
    final db = await _database();
    final key = _dateKey(day);
    final rows = await db.query(
      'tasks',
      where: 'done = 0 AND (due_day IS NULL OR due_day <= ?)',
      whereArgs: [key],
      orderBy: 'due_day IS NULL, due_day ASC, due_time IS NULL, due_time ASC',
    );
    return _hydrateTasks(db, rows);
  }

  /// Alle Aufgaben mit dem gegebenen Tag (case-insensitiv). Grundlage für die
  /// „alles zu einem Tag"-Ansicht und später die Perlenkette. Noch kein
  /// Aufrufer in der UI (wie seinerzeit `dailyInfosForDay` beim Anlegen).
  Future<List<Task>> tasksForTag(String tag) async {
    final db = await _database();
    final rows = await db.rawQuery(
      '''
      SELECT t.* FROM tasks t
      JOIN task_tags tt ON tt.task_id = t.id
      WHERE tt.tag_key = ?
      ORDER BY t.due_day IS NULL, t.due_day ASC,
               t.due_time IS NULL, t.due_time ASC
      ''',
      [tag.toLowerCase()],
    );
    return _hydrateTasks(db, rows);
  }

  /// Alle Aufgaben (für spätere Verwaltungs-/Erledigt-Ansicht). Offene zuerst.
  Future<List<Task>> loadAllTasks() async {
    final db = await _database();
    final rows = await db.query(
      'tasks',
      orderBy:
          'done ASC, due_day IS NULL, due_day ASC, due_time IS NULL, due_time ASC',
    );
    return _hydrateTasks(db, rows);
  }

  /// Legt eine Aufgabe an oder aktualisiert sie (inkl. Tags), transaktional.
  Future<void> upsertTask(Task task) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.insert(
        'tasks',
        {
          'id': task.id,
          'title': task.title,
          'due_day': task.dueDay != null ? _dateKey(task.dueDay!) : null,
          'due_time': task.dueTime,
          'done': task.done ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Tags der Aufgabe neu setzen: erst löschen, dann in Reihenfolge einfügen.
      await txn
          .delete('task_tags', where: 'task_id = ?', whereArgs: [task.id]);
      for (var i = 0; i < task.tags.length; i++) {
        final tag = task.tags[i];
        await txn.insert(
          'task_tags',
          {
            'task_id': task.id,
            'tag': tag,
            'tag_key': tag.toLowerCase(),
            'ord': i,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Löscht eine Aufgabe samt ihrer Tags (task_tags via ON DELETE CASCADE).
  Future<void> deleteTask(String id) async {
    final db = await _database();
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Kalender-Quellen (Schema v4)
  // ---------------------------------------------------------------------------

  /// Baut aus `calendar_sources`-Zeilen [CalendarSource]-Objekte inkl. ihrer
  /// Tags auf. Lädt die Tags in einem Rutsch und ordnet sie über `ord`.
  Future<List<CalendarSource>> _hydrateCalendarSources(
    Database db,
    List<Map<String, Object?>> rows,
  ) async {
    final tagRows = await db.query('calendar_source_tags', orderBy: 'ord ASC');
    final tagsBySource = <String, List<String>>{};
    for (final row in tagRows) {
      final cid = row['calendar_id'] as String;
      (tagsBySource[cid] ??= <String>[]).add(row['tag'] as String);
    }
    return rows.map((row) {
      final cid = row['calendar_id'] as String;
      return CalendarSource(
        calendarId: cid,
        displayName: row['display_name'] as String,
        enabled: (row['enabled'] as int) != 0,
        tags: tagsBySource[cid] ?? const <String>[],
        syncToken: row['sync_token'] as String?,
      );
    }).toList();
  }

  /// Alle Kalender-Quellen, alphabetisch nach Anzeigename.
  Future<List<CalendarSource>> loadCalendarSources() async {
    final db = await _database();
    final rows = await db.query(
      'calendar_sources',
      orderBy: 'display_name COLLATE NOCASE ASC',
    );
    return _hydrateCalendarSources(db, rows);
  }

  /// Legt eine Kalender-Quelle an oder aktualisiert sie (inkl. Tags),
  /// transaktional — spiegelt [upsertTask].
  Future<void> upsertCalendarSource(CalendarSource source) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.insert(
        'calendar_sources',
        {
          'calendar_id': source.calendarId,
          'display_name': source.displayName,
          'enabled': source.enabled ? 1 : 0,
          'sync_token': source.syncToken,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Tags der Quelle neu setzen: erst löschen, dann in Reihenfolge einfügen.
      await txn.delete(
        'calendar_source_tags',
        where: 'calendar_id = ?',
        whereArgs: [source.calendarId],
      );
      for (var i = 0; i < source.tags.length; i++) {
        final tag = source.tags[i];
        await txn.insert(
          'calendar_source_tags',
          {
            'calendar_id': source.calendarId,
            'tag': tag,
            'tag_key': tag.toLowerCase(),
            'ord': i,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Gleicht die lokale Kalenderliste mit der frisch abgerufenen ab
  /// ([fetched] = `calendarId` → Anzeigename). Vorhandene Kalender behalten
  /// `enabled`, Tags und `sync_token`; nur der Anzeigename wird aufgefrischt.
  /// Neue Kalender kommen mit `enabled = 0` und ohne Tags hinzu. Kalender, die
  /// nicht mehr in [fetched] stehen, fallen samt Mapping raus
  /// (`calendar_source_tags` via ON DELETE CASCADE).
  Future<void> mergeCalendarList(Map<String, String> fetched) async {
    final db = await _database();
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'calendar_sources',
        columns: ['calendar_id'],
      );
      final existingIds =
          existingRows.map((r) => r['calendar_id'] as String).toSet();

      for (final entry in fetched.entries) {
        if (existingIds.contains(entry.key)) {
          await txn.update(
            'calendar_sources',
            {'display_name': entry.value},
            where: 'calendar_id = ?',
            whereArgs: [entry.key],
          );
        } else {
          await txn.insert(
            'calendar_sources',
            {
              'calendar_id': entry.key,
              'display_name': entry.value,
              'enabled': 0,
              'sync_token': null,
            },
          );
        }
      }

      for (final id in existingIds) {
        if (!fetched.containsKey(id)) {
          await txn.delete(
            'calendar_sources',
            where: 'calendar_id = ?',
            whereArgs: [id],
          );
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Kalender-Termine (Schema v5)
  // ---------------------------------------------------------------------------

  /// Baut aus `calendar_events`-Zeilen [CalendarEvent]-Objekte inkl. ihrer
  /// Tags auf. Lädt die Tags in einem Rutsch und ordnet sie über `ord`.
  Future<List<CalendarEvent>> _hydrateCalendarEvents(
    Database db,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return <CalendarEvent>[];
    final tagRows = await db.query('event_tags', orderBy: 'ord ASC');
    final tagsByEvent = <String, List<String>>{};
    for (final row in tagRows) {
      final key = '${row['calendar_id']}\u0000${row['event_id']}';
      (tagsByEvent[key] ??= <String>[]).add(row['tag'] as String);
    }
    return rows.map((row) {
      final calendarId = row['calendar_id'] as String;
      final eventId = row['event_id'] as String;
      return CalendarEvent(
        calendarId: calendarId,
        eventId: eventId,
        iCalUid: row['ical_uid'] as String?,
        summary: row['summary'] as String,
        location: row['location'] as String?,
        allDay: (row['all_day'] as int) != 0,
        startDay: row['start_day'] as String,
        startTime: row['start_time'] as String?,
        endDay: row['end_day'] as String,
        endTime: row['end_time'] as String?,
        tags: tagsByEvent['$calendarId\u0000$eventId'] ?? const <String>[],
      );
    }).toList();
  }

  /// Ersetzt **alle** gespiegelten Termine eines Kalenders durch [events].
  ///
  /// Bewusst „löschen und neu schreiben" statt Einzelabgleich: Der Abruf
  /// liefert das vollständige Zeitfenster, also sind verschwundene Termine
  /// genau die abgesagten oder verschobenen. Alles läuft in **einer**
  /// Transaktion — bei einem Abbruch bleibt der alte Stand stehen, statt dass
  /// halbe Kalender im Journal auftauchen.
  Future<void> replaceCalendarEvents(
    String calendarId,
    List<CalendarEvent> events,
  ) async {
    final db = await _database();
    await db.transaction((txn) async {
      // event_tags folgen via ON DELETE CASCADE.
      await txn.delete(
        'calendar_events',
        where: 'calendar_id = ?',
        whereArgs: [calendarId],
      );
      for (final event in events) {
        await txn.insert(
          'calendar_events',
          {
            'calendar_id': event.calendarId,
            'event_id': event.eventId,
            'ical_uid': event.iCalUid,
            'summary': event.summary,
            'location': event.location,
            'all_day': event.allDay ? 1 : 0,
            'start_day': event.startDay,
            'start_time': event.startTime,
            'end_day': event.endDay,
            'end_time': event.endTime,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var i = 0; i < event.tags.length; i++) {
          final tag = event.tags[i];
          await txn.insert(
            'event_tags',
            {
              'calendar_id': event.calendarId,
              'event_id': event.eventId,
              'tag': tag,
              'tag_key': tag.toLowerCase(),
              'ord': i,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  /// Wirft die gespiegelten Termine eines Kalenders weg — beim Deaktivieren
  /// des Kalenders, damit nichts Verwaistes im Journal stehen bleibt.
  Future<void> deleteCalendarEventsFor(String calendarId) async {
    final db = await _database();
    await db.delete(
      'calendar_events',
      where: 'calendar_id = ?',
      whereArgs: [calendarId],
    );
  }

  /// Zieht eine geänderte Kalender→Tag-Zuordnung auf die bereits
  /// gespiegelten Termine nach, ohne neu zu synchronisieren.
  Future<void> reapplyCalendarSourceTags(
    String calendarId,
    List<String> tags,
  ) async {
    final db = await _database();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'calendar_events',
        columns: ['event_id'],
        where: 'calendar_id = ?',
        whereArgs: [calendarId],
      );
      await txn.delete(
        'event_tags',
        where: 'calendar_id = ?',
        whereArgs: [calendarId],
      );
      for (final row in rows) {
        final eventId = row['event_id'] as String;
        for (var i = 0; i < tags.length; i++) {
          final tag = tags[i];
          await txn.insert(
            'event_tags',
            {
              'calendar_id': calendarId,
              'event_id': eventId,
              'tag': tag,
              'tag_key': tag.toLowerCase(),
              'ord': i,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  /// Alle Termine, die einen Kalendertag berühren ([day] als `yyyy-MM-dd`) —
  /// nur aus **aktivierten** Kalendern. Bereichsabfrage wie bei `daily_info`
  /// (Endtag ist inklusiv gespeichert). Ganztägige zuerst, danach nach
  /// Uhrzeit. Das ist die Grundlage der „TERMINE"-Sektion im Journal.
  Future<List<CalendarEvent>> calendarEventsForDay(String day) async {
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT e.* FROM calendar_events e '
      'JOIN calendar_sources s ON s.calendar_id = e.calendar_id '
      'WHERE s.enabled = 1 AND e.start_day <= ? AND e.end_day >= ? '
      "ORDER BY e.all_day DESC, COALESCE(e.start_time, '') ASC, "
      'e.summary COLLATE NOCASE ASC',
      [day, day],
    );
    return _hydrateCalendarEvents(db, rows);
  }

  /// Alle Termine zu einem Tag (case-insensitiv), aufsteigend nach Startzeit —
  /// das Gegenstück zu `tasksForTag` für die „alles zu einem Tag"-Ansicht.
  Future<List<CalendarEvent>> calendarEventsForTag(String tag) async {
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT e.* FROM calendar_events e '
      'JOIN event_tags t '
      '  ON t.calendar_id = e.calendar_id AND t.event_id = e.event_id '
      'JOIN calendar_sources s ON s.calendar_id = e.calendar_id '
      'WHERE s.enabled = 1 AND t.tag_key = ? '
      "ORDER BY e.start_day ASC, COALESCE(e.start_time, '') ASC",
      [tag.toLowerCase()],
    );
    return _hydrateCalendarEvents(db, rows);
  }

  /// Anzahl gespiegelter Termine — für die Statuszeile in den Einstellungen.
  Future<int> countCalendarEvents() async {
    final db = await _database();
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM calendar_events');
    return (rows.first['n'] as int?) ?? 0;
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
