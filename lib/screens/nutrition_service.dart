import 'dart:convert';
import 'package:http/http.dart' as http;

/// ─── CREDENCIALES GEMINI (Google AI Studio — GRATIS) ─────────────────────
/// Obtén tu key gratis en: https://aistudio.google.com
/// 1,500 peticiones/día sin costo, sin tarjeta de crédito
const String _geminiApiKey = 'PEGA_AQUI_TU_API_KEY_DE_GEMINI';

/// ─── MODELO DE ALIMENTO ───────────────────────────────────────────────────
class FoodItem {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingDescription;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingDescription,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'servingDescription': servingDescription,
      };

  factory FoodItem.fromMap(Map<String, dynamic> m) => FoodItem(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        calories: (m['calories'] ?? 0).toDouble(),
        protein: (m['protein'] ?? 0).toDouble(),
        carbs: (m['carbs'] ?? 0).toDouble(),
        fat: (m['fat'] ?? 0).toDouble(),
        servingDescription: m['servingDescription'] ?? '',
      );
}

/// ─── SERVICIO PRINCIPAL ───────────────────────────────────────────────────
class NutritionService {

  // ── BUSCAR ALIMENTOS — dos pasadas: México primero, luego global ──────────
  Future<List<FoodItem>> searchFoods(String query) async {
    if (query.trim().isEmpty) return [];

    final mexicoResults = await _fetchProducts(query, countryTag: 'mexico');
    if (mexicoResults.length >= 3) return mexicoResults;

    final globalResults = await _fetchProducts(query, countryTag: null);

    final ids = mexicoResults.map((f) => f.id).toSet();
    final merged = [
      ...mexicoResults,
      ...globalResults.where((f) => !ids.contains(f.id)),
    ];
    return merged.take(5).toList();
  }

  Future<List<FoodItem>> _fetchProducts(
    String query, {
    required String? countryTag,
  }) async {
    final countryFilter = countryTag != null
        ? '&tagtype_0=countries&tag_contains_0=contains&tag_0=$countryTag'
        : '';

    final uri = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl'
      '?search_terms=${Uri.encodeComponent(query)}'
      '&search_simple=1'
      '&action=process'
      '&json=1'
      '&page_size=30'
      '&lc=es'
      '&fields=id,product_name,product_name_es,product_name_es_MX,'
      'nutriments,countries_tags,languages_tags'
      '$countryFilter',
    );

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'StarNutri/1.0 (Flutter - student project)',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data     = json.decode(response.body) as Map<String, dynamic>;
      final products = data['products'] as List<dynamic>? ?? [];
      final List<FoodItem> results = [];

      for (final p in products) {
        final nameMx  = (p['product_name_es_MX'] as String?)?.trim() ?? '';
        final nameEs  = (p['product_name_es']     as String?)?.trim() ?? '';
        final nameGen = (p['product_name']         as String?)?.trim() ?? '';

        String bestName = '';
        if (nameMx.isNotEmpty) {
          bestName = nameMx;
        } else if (nameEs.isNotEmpty) {
          bestName = nameEs;
        } else if (nameGen.isNotEmpty && _looksSpanish(nameGen)) {
          bestName = nameGen;
        } else if (nameGen.isNotEmpty && results.length < 3) {
          bestName = nameGen;
        }

        if (bestName.isEmpty) continue;

        final n = p['nutriments'] as Map<String, dynamic>? ?? {};

        double calories = _d(n['energy-kcal_100g'] ?? n['energy-kcal_serving']);
        if (calories == 0) {
          final kj = _d(n['energy_100g'] ?? n['energy-kj_100g']);
          if (kj > 0) calories = kj / 4.184;
        }

        final protein = _d(n['proteins_100g']      ?? n['proteins']);
        final carbs   = _d(n['carbohydrates_100g'] ?? n['carbohydrates']);
        final fat     = _d(n['fat_100g']           ?? n['fat']);

        if (calories <= 0 && protein <= 0 && carbs <= 0) continue;

        results.add(FoodItem(
          id:                 (p['id'] ?? p['_id'] ?? '').toString(),
          name:               _capitalize(bestName),
          calories:           calories,
          protein:            protein,
          carbs:              carbs,
          fat:                fat,
          servingDescription: 'Por 100 g — ${calories.toInt()} kcal',
        ));

        if (results.length >= 5) break;
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  // ── GENERAR RECOMENDACIÓN CON GEMINI 1.5 FLASH (GRATIS) ─────────────────
  Future<String> generateRecommendation({
    required String       childName,
    required int          childAge,
    required double       totalCalories,
    required double       totalProtein,
    required double       totalCarbs,
    required double       totalFat,
    required int          waterGlasses,
    required List<String> foodsEaten,
  }) async {
    final int recommended = _recommendedCaloriesByAge(childAge);

    final prompt = '''
Eres un nutriólogo infantil experto en México. Analiza la alimentación de hoy de un niño y da recomendaciones personalizadas en español, de forma amigable para padres mexicanos.

DATOS DEL NIÑO:
- Nombre: $childName
- Edad: $childAge años
- Calorías recomendadas por día: $recommended kcal

LO QUE COMIÓ HOY:
- Alimentos: ${foodsEaten.join(', ')}
- Calorías totales: ${totalCalories.toInt()} kcal
- Proteínas: ${totalProtein.toStringAsFixed(1)} g
- Carbohidratos: ${totalCarbs.toStringAsFixed(1)} g
- Grasas: ${totalFat.toStringAsFixed(1)} g
- Vasos de agua: $waterGlasses

INSTRUCCIONES:
1. Evalúa si las calorías son adecuadas para su edad
2. Identifica qué nutrientes le faltaron o sobraron
3. Da 2-3 recomendaciones concretas usando alimentos típicos de México (frijoles, tortillas, nopales, frutas locales, etc.)
4. Usa un tono positivo y motivador para los padres
5. Máximo 150 palabras
6. Solo texto plano, sin markdown ni asteriscos

Responde directamente sin saludos ni introducciones.
''';

    try {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-1.5-flash:generateContent?key=$_geminiApiKey';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature':     0.7,
            'maxOutputTokens': 400,
            'topP':            0.9,
          },
          'safetySettings': [
            {
              'category':  'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_NONE',
            },
            {
              'category':  'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_NONE',
            },
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}',
        );
      }

      final data       = json.decode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>;
      final content    = candidates.first['content'] as Map<String, dynamic>;
      final parts      = content['parts'] as List<dynamic>;
      return (parts.first['text'] as String).trim();

    } catch (_) {
      // Fallback local si no hay internet o la key falla
      return _recomendacionGenerica(
        childName:     childName,
        totalCalories: totalCalories,
        recommended:   recommended,
        waterGlasses:  waterGlasses,
      );
    }
  }

  // ── FALLBACK local si Gemini no está disponible ───────────────────────────
  String _recomendacionGenerica({
    required String childName,
    required double totalCalories,
    required int    recommended,
    required int    waterGlasses,
  }) {
    final diff    = totalCalories - recommended;
    final diffAbs = diff.abs().toInt();

    String calMsg;
    if (diff < -200) {
      calMsg = '$childName consumió $diffAbs kcal menos de lo recomendado. '
          'Agrega una colación nutritiva como fruta con cacahuate o un vaso de leche.';
    } else if (diff > 200) {
      calMsg = '$childName consumió $diffAbs kcal más de lo recomendado. '
          'Mañana incluye más verduras y reduce los alimentos procesados.';
    } else {
      calMsg =
          '¡Excelente! $childName tuvo un consumo calórico muy adecuado para su edad.';
    }

    final waterMsg = waterGlasses < 6
        ? 'Recuerda que debe tomar al menos 6 vasos de agua al día.'
        : '¡Muy bien con la hidratación!';

    return '$calMsg $waterMsg Incluye frijoles, verduras de colores y fruta fresca en la siguiente comida para un balance perfecto.';
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────
  bool _looksSpanish(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'[áéíóúüñ¿¡]').hasMatch(lower)) return true;
    const words = [
      'de', 'del', 'con', 'sin', 'en', 'para', 'leche', 'queso', 'pollo',
      'carne', 'arroz', 'frijol', 'tortilla', 'pan', 'agua', 'jugo',
      'naranja', 'manzana', 'platano', 'fresa', 'zanahoria', 'tomate',
      'chile', 'nopal', 'aguacate', 'elote', 'tamal', 'chilaquil',
    ];
    return words.any((w) => lower.contains(w));
  }

  double _d(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int)    return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    final clean = text.trim();
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }

  int _recommendedCaloriesByAge(int age) {
    if (age <= 3)  return 1000;
    if (age <= 5)  return 1200;
    if (age <= 8)  return 1400;
    if (age <= 11) return 1600;
    if (age <= 13) return 1800;
    return 2000;
  }
}
