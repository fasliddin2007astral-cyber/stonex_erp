import 'dart:convert';
import 'dart:io';

/// Mahsulot rasmlarini lokal xotirada saqlash va sinxronlash.
///
/// Server hali rasm ustunini qo'llab-quvvatlamagan taqdirda ham rasmlar
/// foydalanuvchining qurilmasida saqlanadi va darhol ko'rinadi.
class LocalImageStore {
  static final Map<String, String> _cache = {};
  static bool _loaded = false;

  static File _getFile() {
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    final dir = Directory('$appData/stonex_erp');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return File('${dir.path}/product_images.json');
  }

  static void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = _getFile();
      if (f.existsSync()) {
        final text = f.readAsStringSync();
        if (text.isNotEmpty) {
          final data = jsonDecode(text) as Map<String, dynamic>;
          for (final e in data.entries) {
            _cache[e.key] = e.value.toString();
          }
        }
      }
    } catch (_) {}
  }

  static String? getImage(int productId, [String? name]) {
    _ensureLoaded();
    if (_cache.containsKey(productId.toString())) {
      return _cache[productId.toString()];
    }
    if (name != null) {
      final nameKey = 'name_${name.trim().toLowerCase()}';
      if (_cache.containsKey(nameKey)) {
        return _cache[nameKey];
      }
    }
    return null;
  }

  static void saveImage(int productId, String? imageUrl, [String? name]) {
    _ensureLoaded();
    final key = productId.toString();
    final nameKey = name != null ? 'name_${name.trim().toLowerCase()}' : null;

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      _cache.remove(key);
      if (nameKey != null) _cache.remove(nameKey);
    } else {
      _cache[key] = imageUrl.trim();
      if (nameKey != null) _cache[nameKey] = imageUrl.trim();
    }

    try {
      final f = _getFile();
      f.writeAsStringSync(jsonEncode(_cache));
    } catch (_) {}
  }
}

