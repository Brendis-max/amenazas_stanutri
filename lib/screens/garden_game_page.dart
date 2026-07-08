import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Palabras del Plato del Buen Comer ───────────────────────────────────────
const List<Map<String, String>> _words = [
  {'word': 'MANZANA',   'emoji': '🍎', 'group': 'Frutas'},
  {'word': 'BROCOLI',   'emoji': '🥦', 'group': 'Verduras'},
  {'word': 'ZANAHORIA', 'emoji': '🥕', 'group': 'Verduras'},
  {'word': 'ARROZ',     'emoji': '🍚', 'group': 'Cereales'},
  {'word': 'TORTILLA',  'emoji': '🫓', 'group': 'Cereales'},
  {'word': 'FRIJOLES',  'emoji': '🫘', 'group': 'Leguminosas'},
  {'word': 'LENTEJAS',  'emoji': '🟤', 'group': 'Leguminosas'},
  {'word': 'POLLO',     'emoji': '🍗', 'group': 'Animal'},
  {'word': 'LECHE',     'emoji': '🥛', 'group': 'Animal'},
  {'word': 'HUEVO',     'emoji': '🍳', 'group': 'Animal'},
];

// Colores por grupo
const Map<String, Color> _groupColors = {
  'Frutas':     Color(0xFFFF6BA1),
  'Verduras':   Color(0xFF4ECB71),
  'Cereales':   Color(0xFFFFD166),
  'Leguminosas':Color(0xFFFF8C42),
  'Animal':     Color(0xFF5DCCFF),
};

// ─── Modelo de celda ─────────────────────────────────────────────────────────
class _Cell {
  String letter;
  bool   selected;
  bool   found;
  String foundGroup;
  _Cell(this.letter, {this.selected = false, this.found = false, this.foundGroup = ''});
}

// ─── Generador de sopa de letras ─────────────────────────────────────────────
class _WordSearchGenerator {
  static const int size = 12;
  final List<List<_Cell>> grid;
  final List<Map<String, dynamic>> placedWords;

  _WordSearchGenerator._({required this.grid, required this.placedWords});

  factory _WordSearchGenerator.generate(List<Map<String, String>> words) {
    final rnd = Random();
    // Init grid with empty
    final grid = List.generate(size, (_) =>
        List.generate(size, (_) => _Cell('')));

    final List<Map<String, dynamic>> placed = [];

    // Directions: right, down, diagonal-right-down, left, up
    final directions = [
      [0, 1], [1, 0], [1, 1], [0, -1], [-1, 0], [-1, 1], [1, -1],
    ];

    for (final wMap in words) {
      final word = wMap['word']!;
      bool wordPlaced = false;
      int attempts = 0;

      while (!wordPlaced && attempts < 200) {
        attempts++;
        final dir = directions[rnd.nextInt(directions.length)];
        final dr = dir[0], dc = dir[1];

        final maxRow = dc == 0 ? size : (dr > 0 ? size - word.length : word.length - 1);
        final maxCol = dr == 0 ? size : (dc > 0 ? size - word.length : word.length - 1);
        final minRow = dr < 0  ? word.length - 1 : 0;
        final minCol = dc < 0  ? word.length - 1 : 0;

        if (maxRow <= minRow || maxCol <= minCol) continue;

        final row = minRow + rnd.nextInt((maxRow - minRow).clamp(1, size));
        final col = minCol + rnd.nextInt((maxCol - minCol).clamp(1, size));

        // Check if fits
        bool fits = true;
        final cells = <List<int>>[];
        for (int i = 0; i < word.length; i++) {
          final r = row + dr * i;
          final c = col + dc * i;
          if (r < 0 || r >= size || c < 0 || c >= size) { fits = false; break; }
          if (grid[r][c].letter.isNotEmpty && grid[r][c].letter != word[i]) {
            fits = false; break;
          }
          cells.add([r, c]);
        }

        if (fits) {
          for (int i = 0; i < word.length; i++) {
            grid[cells[i][0]][cells[i][1]].letter = word[i];
          }
          placed.add({
            'word':  word,
            'emoji': wMap['emoji'],
            'group': wMap['group'],
            'cells': cells,
          });
          wordPlaced = true;
        }
      }
    }

    // Fill empty cells with random letters
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c].letter.isEmpty) {
          grid[r][c].letter = letters[rnd.nextInt(letters.length)];
        }
      }
    }

    return _WordSearchGenerator._(grid: grid, placedWords: placed);
  }
}

// ─── Pantalla principal ───────────────────────────────────────────────────────
class GardenGamePage extends StatefulWidget {
  final String kidName;
  final String userId;
  const GardenGamePage({
    super.key,
    required this.kidName,
    required this.userId,
  });

  @override
  State<GardenGamePage> createState() => _GardenGamePageState();
}

class _GardenGamePageState extends State<GardenGamePage>
    with TickerProviderStateMixin {

  // ─── Animación de fondo ───────────────────────────────────────────────────
  late AnimationController _bgController;

  static const List<Color> _dotColors = [
    Color(0xFFFF6BA1), Color(0xFF7C3AED), Color(0xFF5DCCFF),
    Color(0xFFFF8C42), Color(0xFF4ECB71), Color(0xFFFFD166),
  ];
  late List<_BgDot> _bgDots;

  // ─── Estado del juego ─────────────────────────────────────────────────────
  late _WordSearchGenerator _gen;
  late List<List<_Cell>>     _grid;
  late List<Map<String, dynamic>> _placedWords;

  // Selección actual (drag)
  final List<List<int>> _selection = [];
  List<int>? _dragStart;

  // Palabras encontradas
  final Set<String> _found = {};

  int  _score   = 0;
  bool _gameWon = false;
  String? _lastFound;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this, duration: const Duration(seconds: 24),
    )..repeat();

    final rnd = Random();
    _bgDots = List.generate(20, (i) {
      final r = Random(i * 13 + 9);
      return _BgDot(
        color:   _dotColors[r.nextInt(_dotColors.length)],
        x: r.nextDouble(), y: r.nextDouble(),
        size:    3 + r.nextDouble() * 4.5,
        phase:   rnd.nextDouble() * 2 * pi,
        opacity: 0.30 + r.nextDouble() * 0.35,
      );
    });

    _newGame();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _newGame() {
    _gen = _WordSearchGenerator.generate(_words);
    setState(() {
      _grid        = _gen.grid;
      _placedWords = _gen.placedWords;
      _selection.clear();
      _dragStart = null;
      _found.clear();
      _score    = 0;
      _gameWon  = false;
      _lastFound = null;
    });
  }

  // ─── Lógica de selección ──────────────────────────────────────────────────

  /// Calcula las celdas en línea recta entre start y end
  List<List<int>> _cellsBetween(List<int> start, List<int> end) {
    final dr = (end[0] - start[0]);
    final dc = (end[1] - start[1]);
    final steps = max(dr.abs(), dc.abs());
    if (steps == 0) return [start];

    // Solo aceptamos 8 direcciones exactas
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return [start];

    final stepR = steps == 0 ? 0 : dr ~/ steps;
    final stepC = steps == 0 ? 0 : dc ~/ steps;

    return List.generate(steps + 1, (i) => [start[0] + stepR * i, start[1] + stepC * i]);
  }

  void _onPanStart(int r, int c) {
    setState(() {
      _dragStart = [r, c];
      _selection
        ..clear()
        ..add([r, c]);
    });
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(int r, int c) {
    if (_dragStart == null) return;
    final cells = _cellsBetween(_dragStart!, [r, c]);
    setState(() {
      _selection
        ..clear()
        ..addAll(cells);
    });
  }

  void _onPanEnd() {
    if (_selection.length < 2) { setState(() => _selection.clear()); return; }

    final selected = _selection.map((c) => _grid[c[0]][c[1]].letter).join();
    final reversed = selected.split('').reversed.join();

    for (final pw in _placedWords) {
      final word = pw['word'] as String;
      if (_found.contains(word)) continue;
      if (selected == word || reversed == word) {
        // Match!
        final group = pw['group'] as String;
        final color = _groupColors[group] ?? const Color(0xFF7C3AED);
        HapticFeedback.mediumImpact();

        setState(() {
          _found.add(word);
          _score += 10;
          _lastFound = '${pw['emoji']}  ¡Encontraste ${_capitalize(word.toLowerCase())}!';

          for (final c in _selection) {
            _grid[c[0]][c[1]].found      = true;
            _grid[c[0]][c[1]].foundGroup = group;
          }

          if (_found.length == _placedWords.length) {
            _gameWon = true;
            _savePoints(_score + 15);
            Future.delayed(const Duration(milliseconds: 500), _showWin);
          }
        });

        break;
      }
    }

    setState(() {
      _selection.clear();
      _dragStart = null;
    });
  }

  Future<void> _savePoints(int pts) async {
    if (widget.userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('kids_points').doc(widget.kidName)
          .set({
        'points':      FieldValue.increment(pts),
        'sopa_best':   _found.length,
        'last_played': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _showWin() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _WinDialog(
        score:    _score + 15,
        onReplay: () { Navigator.pop(context); _newGame(); },
        onHome:   () { Navigator.pop(context); Navigator.pop(context); },
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(children: [
        _buildBg(),
        // Dots
        AnimatedBuilder(
          animation: _bgController,
          builder: (_, __) => Stack(
            children: _bgDots.map((d) {
              final dy = sin(_bgController.value * 2 * pi + d.phase) * 10;
              return Positioned(
                left: d.x * size.width,
                top:  d.y * size.height + dy,
                child: Opacity(
                  opacity: d.opacity,
                  child: Container(
                    width: d.size, height: d.size,
                    decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 70, 14, 10),
            child: Column(children: [
              _buildScoreBar(),
              const SizedBox(height: 8),
              if (_lastFound != null) _buildLastFound(),
              const SizedBox(height: 8),
              // Grid
              Expanded(flex: 5, child: _buildGrid()),
              const SizedBox(height: 10),
              // Word list
              Expanded(flex: 3, child: _buildWordList()),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── APP BAR ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.4))),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.5)),
                          ),
                          child: const Center(child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16, color: Color(0xFF1A0A36))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Image.asset(
                    'assets/starnutri2.png', height: 28,
                    errorBuilder: (_, __, ___) =>
                        const Text('🌟', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 8),
                  Text(' ',
                      style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: const Color(0xFF1A0A36))),
                  const Spacer(),
                  // Score badge
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD166).withOpacity(0.28),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.5)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('⭐', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$_score pts',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w900, fontSize: 13,
                                color: const Color(0xFFFF8C42))),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── SCORE BAR ────────────────────────────────────────────────────────────
  Widget _buildScoreBar() {
    return Row(children: [
      _badge('🔍 ${_found.length}/${_placedWords.length}', const Color(0xFF7C3AED)),
      const Spacer(),
      SizedBox(
        width: 120,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(children: [
            Container(height: 8, color: Colors.white.withOpacity(0.30)),
            FractionallySizedBox(
              widthFactor: _placedWords.isEmpty ? 0 : _found.length / _placedWords.length,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6BA1), Color(0xFF7C3AED)]),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ─── LAST FOUND ───────────────────────────────────────────────────────────
  Widget _buildLastFound() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: ClipRRect(
        key: ValueKey(_lastFound),
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4ECB71).withOpacity(0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF4ECB71).withOpacity(0.5)),
            ),
            child: Text(
              _lastFound!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: const Color(0xFF065F46)),
            ),
          ),
        ),
      ),
    );
  }

  // ─── GRID ─────────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.5),
          ),
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(builder: (context, constraints) {
            final cellSize = min(
              constraints.maxWidth  / _WordSearchGenerator.size,
              constraints.maxHeight / _WordSearchGenerator.size,
            );
            return GestureDetector(
              onPanStart: (d) {
                final c = _posToCell(d.localPosition, cellSize);
                if (c != null) _onPanStart(c[0], c[1]);
              },
              onPanUpdate: (d) {
                final c = _posToCell(d.localPosition, cellSize);
                if (c != null) _onPanUpdate(c[0], c[1]);
              },
              onPanEnd: (_) => _onPanEnd(),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _WordSearchGenerator.size,
                  mainAxisSpacing: 1, crossAxisSpacing: 1,
                ),
                itemCount: _WordSearchGenerator.size * _WordSearchGenerator.size,
                itemBuilder: (_, idx) {
                  final r = idx ~/ _WordSearchGenerator.size;
                  final c = idx %  _WordSearchGenerator.size;
                  return _buildCell(r, c, cellSize);
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  List<int>? _posToCell(Offset pos, double cellSize) {
    final r = (pos.dy / cellSize).floor();
    final c = (pos.dx / cellSize).floor();
    if (r < 0 || r >= _WordSearchGenerator.size) return null;
    if (c < 0 || c >= _WordSearchGenerator.size) return null;
    return [r, c];
  }

  Widget _buildCell(int r, int c, double cellSize) {
    final cell = _grid[r][c];
    final isSelected = _selection.any((s) => s[0] == r && s[1] == c);
    final groupColor = cell.found
        ? (_groupColors[cell.foundGroup] ?? const Color(0xFF7C3AED))
        : null;

    Color bg;
    Color textColor;
    double fontSize = (cellSize * 0.48).clamp(9, 16);

    if (cell.found) {
      bg        = groupColor!.withOpacity(0.35);
      textColor = groupColor.withOpacity(0.9);
    } else if (isSelected) {
      bg        = const Color(0xFF7C3AED).withOpacity(0.45);
      textColor = Colors.white;
    } else {
      bg        = Colors.transparent;
      textColor = const Color(0xFF1A0A36);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: cell.found
            ? Border.all(color: groupColor!.withOpacity(0.4), width: 1)
            : isSelected
                ? Border.all(color: const Color(0xFF7C3AED).withOpacity(0.6), width: 1)
                : null,
      ),
      child: Center(
        child: Text(
          cell.letter,
          style: GoogleFonts.nunito(
            fontSize: fontSize,
            fontWeight: cell.found || isSelected ? FontWeight.w900 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ─── WORD LIST ────────────────────────────────────────────────────────────
  Widget _buildWordList() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Busca estas palabras:',
                  style: GoogleFonts.nunito(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: const Color(0xFF50288C).withOpacity(0.75))),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8, runSpacing: 6,
                    children: _placedWords.map((pw) {
                      final word  = pw['word'] as String;
                      final emoji = pw['emoji'] as String;
                      final group = pw['group'] as String;
                      final found = _found.contains(word);
                      final color = _groupColors[group] ?? const Color(0xFF7C3AED);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: found ? color.withOpacity(0.25) : Colors.white.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: found ? color.withOpacity(0.6) : Colors.white.withOpacity(0.5),
                            width: found ? 1.5 : 1,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          Text(
                            _capitalize(word.toLowerCase()),
                            style: GoogleFonts.nunito(
                              fontSize: 12, fontWeight: FontWeight.w800,
                              color: found ? color : const Color(0xFF1A0A36).withOpacity(0.55),
                              decoration: found ? TextDecoration.lineThrough : null,
                              decorationColor: color,
                              decorationThickness: 2,
                            ),
                          ),
                          if (found) ...[
                            const SizedBox(width: 4),
                            Text('✓', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w900)),
                          ],
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FONDO ────────────────────────────────────────────────────────────────
  Widget _buildBg() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: const [
              Color(0xFFD4F4DD), Color(0xFFFFF9E6),
              Color(0xFFFFD7A5), Color(0xFFE0F2E9),
            ],
            transform: GradientRotation(_bgController.value * 2 * pi),
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _badge(String text, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(text,
              style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Win Dialog ───────────────────────────────────────────────────────────────
class _WinDialog extends StatelessWidget {
  final int score;
  final VoidCallback onReplay, onHome;
  const _WinDialog({required this.score, required this.onReplay, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.60), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 70)),
                  const SizedBox(height: 12),
                  Text('¡Encontraste todas!',
                      style: GoogleFonts.nunito(
                        fontSize: 26, fontWeight: FontWeight.w900,
                        color: const Color(0xFF1A0A36))),
                  const SizedBox(height: 8),
                  Text('¡Eres un experto en nutrición! 🌟',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF3C2864).withOpacity(0.65))),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166).withOpacity(0.28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('⭐ +$score puntos',
                        style: GoogleFonts.nunito(
                          fontSize: 24, fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF8C42))),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onReplay,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.5)),
                          ),
                          child: Center(
                            child: Text('🔄 Otra vez',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800, fontSize: 14,
                                  color: const Color(0xFF1A0A36)))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onHome,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text('← Volver',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800, fontSize: 14,
                                  color: Colors.white))),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dot model ────────────────────────────────────────────────────────────────
class _BgDot {
  final Color  color;
  final double x, y, size, phase, opacity;
  const _BgDot({
    required this.color, required this.x, required this.y,
    required this.size, required this.phase, required this.opacity,
  });
}
