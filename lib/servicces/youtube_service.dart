import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeService {
  static final _yt = YoutubeExplode();

  // Duración permitida
  static const int _duracionMinSegundos = 300;   // 5 min
  static const int _duracionMaxSegundos = 1800;  // 30 min

  // Caché: channelUrl → lista de videos
  static final Map<String, List<Map<String, dynamic>>> _cache = {};
  // Caché: handleUrl → channelId real (UCxxxxx)
  static final Map<String, String> _idCache = {};

  static Future<List<Map<String, dynamic>>> obtenerVideosDeCanal(
    String channelUrl, {
    int maxVideos = 100, // ✅ FIX: 100 videos por defecto
  }) async {
    final key = channelUrl.toLowerCase().trim();
    if (_cache.containsKey(key)) return _cache[key]!;

    final channelId = await _resolverChannelId(channelUrl);
    if (channelId == null) {
      debugPrint('⚠️ No se pudo resolver channelId para: $channelUrl');
      _cache[key] = [];
      return [];
    }

    // Intento 1: youtube_explode_dart (soporta filtro de duración)
    try {
      final result = await _videosViaExplode(channelId, maxVideos);
      if (result.isNotEmpty) {
        _cache[key] = result;
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ explode falló para $channelUrl: $e');
    }

    // Intento 2: RSS público de YouTube (sin autenticación, sin filtro duración)
    try {
      final result = await _videosViaRss(channelId, maxVideos);
      _cache[key] = result;
      if (result.isEmpty) debugPrint('⚠️ RSS vacío para $channelUrl');
      return result;
    } catch (e) {
      debugPrint('⚠️ RSS falló para $channelUrl: $e');
      _cache[key] = [];
      return [];
    }
  }

  // ── Método A: youtube_explode_dart ─────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _videosViaExplode(
    String channelId,
    int maxVideos,
  ) async {
    final uploads = _yt.channels.getUploads(ChannelId(channelId));
    final List<Map<String, dynamic>> result = [];

    // Límite de seguridad: revisar hasta 3× el máximo para compensar filtrados
    int revisados = 0;
    final int limiteRevision = maxVideos * 3;

    await for (final video in uploads) {
      if (revisados >= limiteRevision) break;
      revisados++;

      try {
        // ✅ FIX: obtener duración real del video
        final duracionSeg = video.duration?.inSeconds ?? 0;

        // ✅ FIX: filtrar videos fuera del rango de 5 a 30 minutos
        if (duracionSeg < _duracionMinSegundos ||
            duracionSeg > _duracionMaxSegundos) {
          continue;
        }

        final vid = video.id.value;
        result.add({
          'video_id':  vid,
          'titulo':    video.title,
          'canal':     video.author,
          'thumbnail': video.thumbnails.mediumResUrl,
          'duracion':  duracionSeg,
          'categoria': '',
          'rango':     [],
        });
      } catch (_) {
        continue; // video con metadatos incompletos
      }

      if (result.length >= maxVideos) break;
    }

    debugPrint(
      '🎬 Explode: ${result.length} videos válidos '
      '(revisados $revisados) para $channelId',
    );
    return result;
  }

  // ── Método B: RSS feed de YouTube ──────────────────────────────────────────
  // ⚠️ El RSS no incluye duración — se retornan sin filtro de tiempo
  static Future<List<Map<String, dynamic>>> _videosViaRss(
    String channelId,
    int maxVideos,
  ) async {
    final rssUrl =
        'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId';
    final response = await http.get(Uri.parse(rssUrl));
    if (response.statusCode != 200) {
      throw Exception('RSS HTTP ${response.statusCode}');
    }

    final body = response.body;
    final List<Map<String, dynamic>> result = [];

    final entryRegex = RegExp(r'<entry>([\s\S]*?)</entry>');
    for (final entryMatch in entryRegex.allMatches(body)) {
      if (result.length >= maxVideos) break;
      final entry = entryMatch.group(1)!;

      final videoId = _rssField(entry, r'<yt:videoId>(.*?)</yt:videoId>');
      final titulo  = _rssField(entry, r'<title>(.*?)</title>');
      final canal   = _rssField(entry, r'<name>(.*?)</name>');

      if (videoId == null) continue;

      result.add({
        'video_id':  videoId,
        'titulo':    titulo ?? '',
        'canal':     canal  ?? '',
        'thumbnail': 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
        'duracion':  0, // RSS no provee duración
        'categoria': '',
        'rango':     [],
      });
    }

    debugPrint('📡 RSS: ${result.length} videos para $channelId');
    return result;
  }

  static String? _rssField(String xml, String pattern) =>
      RegExp(pattern).firstMatch(xml)?.group(1);

  // ── Resolución de handle → UCxxxxxxxx ──────────────────────────────────────
  static Future<String?> _resolverChannelId(String url) async {
    if (_idCache.containsKey(url)) return _idCache[url];

    // Si ya es un ID directo
    if (RegExp(r'^UC[a-zA-Z0-9_-]{22}$').hasMatch(url)) {
      _idCache[url] = url;
      return url;
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'es-ES,es;q=0.9',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('⚠️ HTTP ${response.statusCode} para $url');
        return null;
      }

      final patterns = [
        RegExp(r'"channelId":"(UC[a-zA-Z0-9_-]{22})"'),
        RegExp(r'"externalChannelId":"(UC[a-zA-Z0-9_-]{22})"'),
        RegExp(r'"browseId":"(UC[a-zA-Z0-9_-]{22})"'),
        RegExp(r'/channel/(UC[a-zA-Z0-9_-]{22})'),
        RegExp(r'data-channel-external-id="(UC[a-zA-Z0-9_-]{22})"'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(response.body);
        if (match != null) {
          final id = match.group(1)!;
          _idCache[url] = id;
          debugPrint('✅ Resuelto $url → $id');
          return id;
        }
      }

      debugPrint('⚠️ No se encontró channelId en $url');
      return null;
    } catch (e) {
      debugPrint('⚠️ Error resolviendo $url: $e');
      return null;
    }
  }

  static void limpiarCache() {
    _cache.clear();
    _idCache.clear();
  }

  static void dispose() => _yt.close();
}