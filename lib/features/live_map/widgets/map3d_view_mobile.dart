import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../data/models/vehicle.dart';

class Map3DView extends StatefulWidget {
  final List<Vehicle> vehicles;
  final LatLng? mapCenter;
  final Vehicle? selectedVehicle;

  const Map3DView({
    super.key,
    required this.vehicles,
    this.mapCenter,
    this.selectedVehicle,
  });

  @override
  State<Map3DView> createState() => _Map3DViewState();
}

class _Map3DViewState extends State<Map3DView> {
  late final WebViewController _controller;
  bool _mapReady = false;
  String? _carBase64;
  String? _vespaBase64;

  String _buildHtml(double lat, double lng) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no"/>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/maplibre-gl/4.7.1/maplibre-gl.min.css"/>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/maplibre-gl/4.7.1/maplibre-gl.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, #map { width: 100%; height: 100%; overflow: hidden; background: #e8e0d8; }
    .vehicle-marker {
      position: relative;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
    }
    .vehicle-marker img {
      display: block;
      object-fit: contain;
      pointer-events: none;
      filter: drop-shadow(0px 4px 8px rgba(0,0,0,0.5));
    }
    .vehicle-marker.selected::before {
      content: '';
      position: absolute;
      top: 50%; left: 50%;
      width: 100%; height: 100%;
      border-radius: 50%;
      border: 3px solid rgba(66,133,244,0.9);
      animation: pulse 1.4s ease-out infinite;
      pointer-events: none;
    }
    @keyframes pulse {
      0%   { transform: translate(-50%,-50%) scale(1.0); opacity: 0.9; }
      100% { transform: translate(-50%,-50%) scale(2.2); opacity: 0; }
    }
  </style>
</head>
<body>
<div id="map"></div>
<script>
  var mapLoaded = false;
  var markers = {};

  var map = new maplibregl.Map({
    container: 'map',
    style: 'https://tiles.openfreemap.org/styles/positron',
    center: [$lng, $lat],
    zoom: 17,
    pitch: 60,
    bearing: 0,
    antialias: true
  });

  map.on('load', function() {
    mapLoaded = true;

    // ── 3-D buildings ────────────────────────────────────────────
    var sources = map.getStyle().sources;
    var sourceId = Object.keys(sources).find(function(k) {
      return sources[k].type === 'vector';
    });
    if (sourceId) {
      map.addLayer({
        id: '3d-buildings',
        source: sourceId,
        'source-layer': 'building',
        type: 'fill-extrusion',
        minzoom: 14,
        paint: {
          'fill-extrusion-color': '#d8d2ca',
          'fill-extrusion-height': ['get', 'render_height'],
          'fill-extrusion-base': ['get', 'render_min_height'],
          'fill-extrusion-opacity': 0.95
        }
      });
    }

    // Update roads to dark grey
    var layers = map.getStyle().layers;
    layers.forEach(function(l) {
      if (l['source-layer'] === 'transportation' && l.type === 'line') {
        map.setPaintProperty(l.id, 'line-color', '#555555');
      }
    });

    if (window.FlutterChannel) {
      window.FlutterChannel.postMessage(JSON.stringify({ type: 'mapReady' }));
    }
  });

  function updateVehicles(vehicles) {
    if (!mapLoaded || !window.carUri) return;

    var activeIds = {};
    vehicles.forEach(function(v) {
      activeIds[v.id] = true;
      var id       = v.id;
      var isVespa  = v.type === 'bike' || v.type === 'scooter';
      var heading  = v.heading || 0;
      var selected = v.selected || false;
      var size     = selected ? 56 : 44;
      var uri      = isVespa ? (window.vespaUri || window.carUri) : window.carUri;

      if (!markers[id]) {
        var el = document.createElement('div');
        el.className = 'vehicle-marker' + (selected ? ' selected' : '');
        el.style.width  = size + 'px';
        el.style.height = size + 'px';

        var img = document.createElement('img');
        img.src = uri;
        img.style.width  = size + 'px';
        img.style.height = size + 'px';
        img.style.transform = 'rotate(' + heading + 'deg)';
        el.appendChild(img);

        el.addEventListener('click', function(e) {
          e.stopPropagation();
          if (window.FlutterChannel) {
            window.FlutterChannel.postMessage(JSON.stringify({ type: 'vehicleTap', id: id }));
          }
        });

        var marker = new maplibregl.Marker({
          element: el,
          anchor: 'center',
          pitchAlignment: 'map',
          rotationAlignment: 'map'
        }).setLngLat([v.lng, v.lat]).addTo(map);

        markers[id] = { marker: marker, el: el, img: img };
      } else {
        var m = markers[id];
        m.marker.setLngLat([v.lng, v.lat]);
        var newUri = isVespa ? (window.vespaUri || window.carUri) : window.carUri;
        if (m.img.src !== newUri) m.img.src = newUri;
        m.img.style.transform = 'rotate(' + heading + 'deg)';
        m.el.style.width  = size + 'px';
        m.el.style.height = size + 'px';
        m.img.style.width  = size + 'px';
        m.img.style.height = size + 'px';
        m.el.className = 'vehicle-marker' + (selected ? ' selected' : '');
      }
    });

    // Remove markers for vehicles no longer in the list
    Object.keys(markers).forEach(function(id) {
      if (!activeIds[id]) {
        markers[id].marker.remove();
        delete markers[id];
      }
    });
  }

  // CAMERA
  // • pitch  60°  → matches reference screenshot perspective
  // • zoom   18    → street-level, road labels visible
  // • bearing = vehicle heading so road faces “up”
  // • padding.top = 26 % of H  → vehicle appears ~63 % from top
  // • padding.left = 150 px   → offsets right to centre in the free
  //   map space beside the left HUD panel
  function centerMap(lng, lat, heading) {
    if (!mapLoaded) return;
    map.easeTo({
      center: [lng, lat],
      bearing: heading || 0,
      pitch: 60,
      zoom: 18,
      padding: {
        top:    Math.round(window.innerHeight * 0.26),
        bottom: 0,
        left:   150,
        right:  0
      },
      duration: 800,
      easing: function(t) { return t < 0.5 ? 2*t*t : -1+(4-2*t)*t; }
    });
  }

  function zoomIn()  { if (mapLoaded) map.zoomIn({ duration: 300 }); }
  function zoomOut() { if (mapLoaded) map.zoomOut({ duration: 300 }); }
</script>
</body>
</html>''';
  }

  @override
  void initState() {
    super.initState();
    _loadSprites();

    final double lat = widget.mapCenter?.latitude ?? 17.385;
    final double lng = widget.mapCenter?.longitude ?? 78.4867;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFE8E0D8))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final dynamic msg = jsonDecode(message.message);
            if (msg['type'] == 'mapReady') {
              setState(() => _mapReady = true);
              _injectSprites().then((_) => _sendVehicles());
              _sendCenter();
            }
          } catch (_) {}
        },
      )
      ..loadHtmlString(_buildHtml(lat, lng),
          baseUrl: 'https://app.fueltracks.com');
  }

  Future<void> _loadSprites() async {
    try {
      final carData  = await rootBundle.load('assets/images/vehicles/white_car.png');
      final bikeData = await rootBundle.load('assets/images/vehicles/bike.png');
      _carBase64   = base64Encode(carData.buffer.asUint8List());
      _vespaBase64 = base64Encode(bikeData.buffer.asUint8List());
      if (_mapReady) await _injectSprites();
    } catch (e) {
      debugPrint('[Map3DView] sprite load error: $e');
    }
  }

  /// Stream a large base64 string into a JS window variable in chunks
  /// to avoid hitting the WebView JS string-length limit.
  Future<void> _injectBase64(
      String varName, String mimeType, String b64) async {
    await _controller
        .runJavaScript("window.$varName = 'data:$mimeType;base64,';");
    const int chunkSize = 40000;
    for (int i = 0; i < b64.length; i += chunkSize) {
      final int end =
          (i + chunkSize < b64.length) ? i + chunkSize : b64.length;
      await _controller
          .runJavaScript("window.$varName += '${b64.substring(i, end)}';");
    }
  }

  Future<void> _injectSprites() async {
    if (!_mapReady || _carBase64 == null || _vespaBase64 == null) return;
    await _injectBase64('carUri',   'image/png', _carBase64!);
    await _injectBase64('vespaUri', 'image/png', _vespaBase64!);
    _sendVehicles();
  }

  void _sendVehicles() {
    if (!_mapReady) return;
    final String? followingId = widget.selectedVehicle?.id;
    final List<Map<String, dynamic>> list = widget.vehicles
        .where((Vehicle v) => v.hasLocation)
        .map((Vehicle v) => <String, dynamic>{
              'id': v.id,
              'lat': v.latitude,
              'lng': v.longitude,
              'heading': v.heading,
              'status': v.status.name,
              'name': v.displayName,
              'type': v.displayType,
              'selected': v.id == followingId,
            })
        .toList();
    final String jsonStr = jsonEncode(list);
    final String escaped = jsonEncode(jsonStr);
    _controller.runJavaScript('updateVehicles(JSON.parse($escaped));');
  }

  void _sendCenter() {
    if (!_mapReady) return;
    if (widget.selectedVehicle != null) {
      final Vehicle v = widget.selectedVehicle!;
      _controller.runJavaScript(
          'centerMap(${v.longitude}, ${v.latitude}, ${v.heading});');
    } else if (widget.mapCenter != null) {
      _controller.runJavaScript(
          'centerMap(${widget.mapCenter!.longitude},'
          ' ${widget.mapCenter!.latitude}, 0);');
    }
  }

  @override
  void didUpdateWidget(covariant Map3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;

    final bool vehiclesChanged = widget.vehicles != oldWidget.vehicles;
    final bool selectedChanged =
        widget.selectedVehicle?.id != oldWidget.selectedVehicle?.id;
    final bool centerChanged =
        widget.mapCenter != oldWidget.mapCenter && widget.mapCenter != null;

    if (vehiclesChanged || selectedChanged) _sendVehicles();
    if (selectedChanged || centerChanged) _sendCenter();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
