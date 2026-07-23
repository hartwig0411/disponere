import 'package:flutter/material.dart';

import '../../services/claude_service.dart';

/// Kühles Blau wie im Journal. Provisorisch, solange die App-Theme-
/// Entscheidung nicht umgesetzt ist.
const Color _kAccent = Color(0xFF4A90D9);
const Color _kBg = Color(0xFF1A1A2E);

/// Einstellungen → Claude.
///
/// Hier wird der eigene API-Schlüssel hinterlegt, geprüft und gelöscht. Der
/// Schlüssel liegt im Android-Keystore (`flutter_secure_storage`) und ist
/// nirgends im Code hinterlegt — das Repository ist öffentlich, jeder, der
/// Disponere baut, trägt seinen eigenen ein (Architektur §10).
class ClaudeSettingsScreen extends StatefulWidget {
  const ClaudeSettingsScreen({super.key});

  @override
  State<ClaudeSettingsScreen> createState() => _ClaudeSettingsScreenState();
}

class _ClaudeSettingsScreenState extends State<ClaudeSettingsScreen> {
  final ClaudeService _claude = ClaudeService();
  final TextEditingController _keyController = TextEditingController();

  bool _busy = true;
  bool _hasKey = false;
  bool _testing = false;
  bool _obscure = true;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final hasKey = await _claude.hasKey();
    if (!mounted) return;
    setState(() {
      _hasKey = hasKey;
      _busy = false;
    });
  }

  void _report(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
  }

  /// Speichert den eingegebenen Schlüssel und leert das Eingabefeld sofort —
  /// ein Schlüssel muss nicht länger auf dem Bildschirm stehen als nötig.
  Future<void> _save() async {
    final value = _keyController.text;
    if (value.trim().isEmpty) {
      _report('Bitte zuerst einen Schlüssel einfügen.', isError: true);
      return;
    }
    try {
      await _claude.saveKey(value);
      _keyController.clear();
      await _refresh();
      _report('Schlüssel gespeichert. Jetzt am besten die Verbindung testen.');
    } catch (e) {
      _report(e.toString(), isError: true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Schlüssel löschen?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Die Tinten-Auswertung steht danach nicht mehr zur Verfügung, bis '
          'ein neuer Schlüssel hinterlegt ist. Bereits erkannte Texte bleiben '
          'erhalten.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Abbrechen',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Löschen',
              style: TextStyle(color: Color(0xFFD96A6A)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _claude.deleteKey();
    await _refresh();
    _report('Schlüssel gelöscht.');
  }

  /// Schickt einen minimalen Request. So scheitert die Einrichtung sichtbar
  /// hier und nicht erst beim ersten echten Aufruf.
  Future<void> _test() async {
    setState(() {
      _testing = true;
      _message = null;
    });
    try {
      await _claude.testConnection();
      _report('Verbindung steht — der Schlüssel wurde akzeptiert.');
    } on ClaudeException catch (e) {
      _report(e.message, isError: true);
    } catch (e) {
      _report(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        iconTheme: const IconThemeData(color: Colors.white54),
        title: const Text(
          'CLAUDE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Icon(
                _hasKey ? Icons.check_circle_outline : Icons.link_off,
                color: _hasKey ? _kAccent : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                _hasKey ? 'Schlüssel hinterlegt' : 'Kein Schlüssel hinterlegt',
                style: TextStyle(
                  color: _hasKey ? Colors.white70 : Colors.white38,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Der Schlüssel liegt verschlüsselt auf diesem Gerät und wird nur '
            'an api.anthropic.com geschickt. Aufrufe laufen über dein eigenes '
            'Anthropic-Konto.',
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
          const SizedBox(height: 32),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kAccent,
                  ),
                ),
              ),
            )
          else ...[
            Text(
              _hasKey ? 'Schlüssel ersetzen' : 'Schlüssel eintragen',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'sk-ant-…',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF16213E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38,
                    size: 20,
                  ),
                  tooltip: _obscure ? 'Anzeigen' : 'Verbergen',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Am bequemsten aus der Zwischenablage einfügen — hundert Zeichen '
              'auf dem Tablet abzutippen ist keine Bedienung.',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Speichern'),
            ),
            if (_hasKey) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kAccent,
                  side: BorderSide(color: _kAccent.withValues(alpha: 0.5)),
                ),
                onPressed: _testing ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kAccent,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(_testing ? 'Testet …' : 'Verbindung testen'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD96A6A),
                ),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Schlüssel löschen'),
              ),
            ],
          ],
          if (_message != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_messageIsError
                        ? const Color(0xFFD96A6A)
                        : const Color(0xFF4A90D9))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _message!,
                style: TextStyle(
                  color: _messageIsError
                      ? const Color(0xFFD96A6A)
                      : Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          const Text(
            'WAS CLAUDE HIER TUT',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nur auf Knopfdruck. Es gibt keine Hintergrundverarbeitung und '
            'keinen Schreibzugriff aufs Journal ohne deine Bestätigung.\n\n'
            '• Tinten-Auswertung: ein handschriftlicher Eintrag wird als Bild '
            'geschickt und kommt als Text zurück. Die Tinte selbst bleibt '
            'unverändert.',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Modell: ${ClaudeService.model}',
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
