import 'package:flutter/material.dart';

/// Tag-Eingabefeld mit Autocomplete.
///
/// Zeigt unter dem Feld passende, bereits bekannte Tags als antippbare Chips.
/// Getippt wird ein '#'-getrennter String (z.B. "#MBS #ValSys"); die
/// Vorschläge beziehen sich auf das gerade getippte (letzte) Fragment.
/// Findet sich kein direkter Treffer, wird per Fuzzy-Match ein
/// "Meintest du …?"-Vorschlag angeboten.
class TagAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> knownTags;

  const TagAutocompleteField({
    super.key,
    required this.controller,
    required this.knownTags,
  });

  @override
  State<TagAutocompleteField> createState() => _TagAutocompleteFieldState();
}

class _TagAutocompleteFieldState extends State<TagAutocompleteField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Das gerade getippte Fragment = Text nach dem letzten '#', getrimmt.
  String get _fragment {
    final text = widget.controller.text;
    final lastHash = text.lastIndexOf('#');
    final raw = lastHash == -1 ? text : text.substring(lastHash + 1);
    return raw.trim();
  }

  List<_Suggestion> get _suggestions {
    final frag = _fragment;
    if (frag.isEmpty) return const <_Suggestion>[];
    final fragLower = frag.toLowerCase();

    // Bereits exakt getippte Tags nicht erneut vorschlagen.
    final pool =
        widget.knownTags.where((t) => t.toLowerCase() != fragLower).toList();

    // 1) Substring-Treffer (Prefix zuerst).
    final contains = pool
        .where((t) => t.toLowerCase().contains(fragLower))
        .toList()
      ..sort((a, b) {
        final ap = a.toLowerCase().startsWith(fragLower) ? 0 : 1;
        final bp = b.toLowerCase().startsWith(fragLower) ? 0 : 1;
        if (ap != bp) return ap - bp;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    if (contains.isNotEmpty) {
      return contains
          .take(5)
          .map((t) => _Suggestion(t, isFuzzy: false))
          .toList();
    }

    // 2) Kein Substring-Treffer → Fuzzy ("Meintest du …?"),
    //    erst ab 3 Zeichen und geringer Editierdistanz.
    if (frag.length >= 3) {
      final fuzzy = pool
          .map((t) => MapEntry(t, _levenshtein(fragLower, t.toLowerCase())))
          .where((e) => e.value <= 2)
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      if (fuzzy.isNotEmpty) {
        return fuzzy
            .take(3)
            .map((e) => _Suggestion(e.key, isFuzzy: true))
            .toList();
      }
    }
    return const <_Suggestion>[];
  }

  void _apply(String tag) {
    final text = widget.controller.text;
    final lastHash = text.lastIndexOf('#');
    final prefix = lastHash == -1 ? '' : text.substring(0, lastHash + 1);
    final newText = '$prefix$tag #';
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final isFuzzy = suggestions.isNotEmpty && suggestions.first.isFuzzy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Tags mit #  ·  z.B. #MBS #ValSys',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (isFuzzy)
            const Padding(
              padding: EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                'Meintest du …?',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map((s) => _SuggestionChip(
                      label: s.tag,
                      onTap: () => _apply(s.tag),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _Suggestion {
  final String tag;
  final bool isFuzzy;
  const _Suggestion(this.tag, {required this.isFuzzy});
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            '#$label',
            style: const TextStyle(color: Color(0xFF4A90D9), fontSize: 13),
          ),
        ),
      ),
    );
  }
}

/// Einfache Levenshtein-Distanz für den Fuzzy-Vorschlag.
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);
  for (int i = 0; i < a.length; i++) {
    curr[0] = i + 1;
    for (int j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      curr[j + 1] = [
        curr[j] + 1,
        prev[j + 1] + 1,
        prev[j] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    for (int j = 0; j <= b.length; j++) {
      prev[j] = curr[j];
    }
  }
  return prev[b.length];
}