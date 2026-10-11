import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';

/// ─────────────────────────────────────────────────────────────────────
///  ULTRA-FAST GLOBAL CDN MAP TILE SOURCES & DISK CACHE
/// ─────────────────────────────────────────────────────────────────────

/// Dedicated disk & RAM cache manager for map tiles.
/// Retains tiles for 30 days with up to 3,000 cached tiles.
/// Previously viewed map regions load in 0ms without hitting the network.
class MapTileCacheManager {
  static const String key = 'fueltracks_map_tiles_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 3000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

/// High-performance cached tile provider backed by [CachedNetworkImageProvider].
/// Provides instant memory and persistent disk caching for buttery-smooth panning.
class FastCachedTileProvider extends TileProvider {
  FastCachedTileProvider({
    this.cacheManager,
    super.headers,
  });

  final BaseCacheManager? cacheManager;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final String url = getTileUrl(coordinates, options);
    return CachedNetworkImageProvider(
      url,
      cacheManager: cacheManager ?? MapTileCacheManager.instance,
      headers: headers,
    );
  }
}

enum MapStyle { standard, satellite, google }

extension MapStyleX on MapStyle {
  String get label => switch (this) {
        MapStyle.standard => 'Modern Light',
        MapStyle.satellite => 'Satellite (Google)',
        MapStyle.google => 'Google Maps',
      };

  IconData get icon => switch (this) {
        MapStyle.standard => Icons.map_rounded,
        MapStyle.satellite => Icons.satellite_alt_rounded,
        MapStyle.google => Icons.public,
      };

  String urlTemplate(String? apiKey) => switch (this) {
        MapStyle.standard =>
          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        MapStyle.satellite =>
          'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}${apiKey != null && apiKey.isNotEmpty ? '&key=$apiKey' : ''}', // Google Hybrid (Satellite + Labels)
        MapStyle.google =>
          'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}${apiKey != null && apiKey.isNotEmpty ? '&key=$apiKey' : ''}', // Google Maps Roadmap
      };

  List<String> get subdomains => switch (this) {
        MapStyle.standard => const <String>['a', 'b', 'c'],
        MapStyle.satellite => const <String>['0', '1', '2', '3'],
        MapStyle.google => const <String>['0', '1', '2', '3'],
      };

  /// Max zoom the source serves reliably everywhere.
  double get maxZoom => switch (this) {
        MapStyle.satellite => 20,
        MapStyle.google => 20,
        _ => 19,
      };

  String get attribution => switch (this) {
        MapStyle.standard => 'OpenStreetMap',
        MapStyle.satellite => 'Google Maps',
        MapStyle.google => 'Google Maps',
      };

  static MapStyle fromKey(String key) => MapStyle.values.firstWhere(
        (MapStyle s) => s.name == key,
        orElse: () => MapStyle.google,
      );
}

/// Builds the ultra-fast tile layer for a given style.
Widget buildTileLayer(
  MapStyle style, {
  bool retina = false,
  String? apiKey,
  bool isDark = false,
}) {
  final TileLayer layer = TileLayer(
    key: ValueKey<String>('tile_layer_${style.name}'),
    urlTemplate: style.urlTemplate(apiKey),
    subdomains: style.subdomains,
    maxNativeZoom: style.maxZoom.toInt(),
    maxZoom: 22.0,
    userAgentPackageName: AppConfig.tileUserAgent,
    tileProvider: kIsWeb ? null : FastCachedTileProvider(),
    retinaMode: false,
    panBuffer: 1,
    keepBuffer: 2,
    tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 100)),
    errorTileCallback: (TileImage tile, Object error, StackTrace? _) {},
  );

  if (isDark) {
    // Basic color inversion + hue shift for dark mode tiles
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -1.0, 0.0, 0.0, 0.0, 255.0, // R
        0.0, -1.0, 0.0, 0.0, 255.0, // G
        0.0, 0.0, -1.0, 0.0, 255.0, // B
        0.0, 0.0, 0.0, 1.0, 0.0,    // A
      ]),
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.blueGrey,
          BlendMode.saturation, // Optional: slightly desaturate
        ),
        child: layer,
      ),
    );
  }

  return layer;
}

/// ODbL-compliant attribution widget.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({required this.style, this.compact = false, super.key});

  final MapStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GestureDetector(
      onTap: () async {
        final Uri uri = Uri.parse('https://www.openstreetmap.org/copyright');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.72),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
          ),
        ),
        child: Text(
          compact ? '© ${style.label}' : '© ${style.attribution}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 8.5,
            letterSpacing: 0,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
