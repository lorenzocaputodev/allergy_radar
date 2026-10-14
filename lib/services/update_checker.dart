import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  UpdateChecker(this._http);

  final http.Client _http;

  static final latestUri = Uri.https('api.github.com', '/repos/lorenzocaputodev/allergy_radar/releases/latest');
  static final releasePage = Uri.https('github.com', '/lorenzocaputodev/allergy_radar/releases/latest');

  Future<String> latestVersion() async {
    final res = await _http
        .get(latestUri, headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw UpdateException('GitHub ha risposto ${res.statusCode}');
    final tag = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['tag_name'];
    final version = tag is String ? tag.replaceFirst(RegExp('^v'), '') : null;
    if (version == null || _parts(version) == null) throw const UpdateException('Versione non riconosciuta');
    return version;
  }

  static Future<bool> openReleasePage() async {
    try {
      return await launchUrl(releasePage, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  static bool isNewer(String candidate, String current) {
    final a = _parts(candidate);
    final b = _parts(current);
    if (a == null || b == null) return false;
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static List<int>? _parts(String version) {
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(version.trim());
    return m == null ? null : [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
