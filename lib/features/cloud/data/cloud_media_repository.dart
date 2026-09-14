import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/cloud_api.dart';
import 'cloud_api_client.dart';

/// Upload foto ke storage cloud (S3 signed URL, spec/10 §4 / API.md §3):
/// minta signed URL → PUT biner langsung ke storage → simpan `publicUrl`.
class CloudMediaRepository {
  final CloudApiClient _api;
  final http.Client _http;
  const CloudMediaRepository(this._api, this._http);

  /// Upload gambar katalog; return `publicUrl` untuk dikirim sebagai `photoUrl`.
  Future<String> uploadCatalogImage(File file) async {
    final bytes = await file.readAsBytes();
    final contentType = _contentType(file.path);
    final fileName = file.path.split(Platform.pathSeparator).last;

    final json = await _api.postJson('/v1/media/sign-upload', {
      'scope': 'catalog',
      'fileName': fileName,
      'contentType': contentType,
      'size': bytes.length,
    });
    final data = json['data'] as Map<String, dynamic>;
    final uploadUrl = data['uploadUrl'] as String;
    final publicUrl = data['publicUrl'] as String;
    final headers = (data['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ) ??
        {'Content-Type': contentType};

    final res =
        await _http.put(Uri.parse(uploadUrl), headers: headers, body: bytes);
    if (res.statusCode >= 300) {
      throw CloudException('Upload gambar gagal (${res.statusCode})',
          statusCode: res.statusCode);
    }
    return publicUrl;
  }

  String _contentType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
