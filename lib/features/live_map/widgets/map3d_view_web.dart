// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../../../data/models/vehicle.dart';

int _factorySeq = 0;

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
  late final String _viewId;
  late final html.IFrameElement _iframe;
  bool _mapReady = false;
  late final StreamSubscription<html.MessageEvent> _sub;
  Timer? _retryTimer;
  String? _carBase64;
  String? _vespaBase64;

  String _buildHtml(double lat, double lng) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>3D Live Map</title>
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no"/>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/maplibre-gl/4.7.1/maplibre-gl.min.css"/>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/maplibre-gl/4.7.1/maplibre-gl.js"></script>
  <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.0.0/model-viewer.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, #map { width: 100%; height: 100%; overflow: hidden; background: #10111a; }
  </style>
</head>
<body>
<div id="map"></div>
<script>
  var mapLoaded = false;
  var markers = {};
  var carUri = null;
  var vespaUri = null;

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
    
    // Add 3D buildings
    var sources = map.getStyle().sources;
    var sourceId = Object.keys(sources).find(k => sources[k].type === 'vector');
    if (sourceId) {
      map.addLayer({
        'id': '3d-buildings',
        'source': sourceId,
        'source-layer': 'building',
        'type': 'fill-extrusion',
        'minzoom': 14,
        'paint': {
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

    window.parent.postMessage(JSON.stringify({ type: 'mapReady' }), '*');
  });

  function checkAndAddModels() {
    // no-op
  }

  function updateVehicles(vehicles) {
    if (!mapLoaded || !carUri) return;

    var activeIds = {};
    vehicles.forEach(function(v) {
      activeIds[v.id] = true;
      var id       = v.id;
      var isVespa  = v.type === 'bike' || v.type === 'scooter';
      var heading  = v.heading || 0;
      var selected = v.selected || false;
      var size     = selected ? 56 : 44;
      var uri      = isVespa ? (vespaUri || carUri) : carUri;

      if (!markers[id]) {
        var el = document.createElement('div');
        el.className = 'vehicle-marker' + (selected ? ' selected' : '');
        el.style.cssText = 'position:relative;display:flex;align-items:center;justify-content:center;cursor:pointer;width:' + size + 'px;height:' + size + 'px';

        var img = document.createElement('img');
        img.src = uri;
        img.style.cssText = 'display:block;object-fit:contain;pointer-events:none;width:' + size + 'px;height:' + size + 'px;transform:rotate(' + heading + 'deg);filter:drop-shadow(0px 4px 8px rgba(0,0,0,0.5))';
        el.appendChild(img);

        el.addEventListener('click', function(e) {
          e.stopPropagation();
          window.parent.postMessage(JSON.stringify({ type: 'vehicleTap', id: id }), '*');
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
        var newUri = isVespa ? (vespaUri || carUri) : carUri;
        if (m.img.src !== newUri) m.img.src = newUri;
        m.img.style.transform = 'rotate(' + heading + 'deg)';
        var s = size + 'px';
        m.el.style.width = s; m.el.style.height = s;
        m.img.style.width = s; m.img.style.height = s;
        m.el.className = 'vehicle-marker' + (selected ? ' selected' : '');
      }
    });

    Object.keys(markers).forEach(function(id) {
      if (!activeIds[id]) { markers[id].marker.remove(); delete markers[id]; }
    });
  }

  window.addEventListener('message', function(event) {
    try {
      var msg = JSON.parse(event.data);
      if (msg.type === 'updateVehicles') {
        updateVehicles(msg.vehicles);
      } else if (msg.type === 'centerMap') {
        if (mapLoaded) {
          map.easeTo({
            center: [msg.lng, msg.lat],
            bearing: msg.heading || 0,
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
      } else if (msg.type === 'addModels') {
        carUri = msg.carUri;
        vespaUri = msg.vespaUri;
        checkAndAddModels();
      }
    } catch(e) {}
  });
</script>
</body>
</html>''';
  }

  @override
  void initState() {
    super.initState();
    _factorySeq++;
    _viewId = 'map3d-view-$_factorySeq';
    _loadModels();

    final double lat = widget.mapCenter?.latitude ?? 17.385;
    final double lng = widget.mapCenter?.longitude ?? 78.4867;

    final blob = html.Blob([_buildHtml(lat, lng)], 'text/html');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);

    _iframe = html.IFrameElement()
      ..src = blobUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'fullscreen';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) => _iframe);

    _sub = html.window.onMessage.listen((html.MessageEvent event) {
      try {
        final raw = event.data;
        final msg = raw is String ? jsonDecode(raw) as Map<String, dynamic> : raw as Map<String, dynamic>;
        if (msg['type'] == 'mapReady') {
          _mapReady = true;
          _checkAndInjectModels();
          _sendVehicles();
          _sendCenter();
        }
      } catch (_) {}
    });

    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timer.tick > 15) { timer.cancel(); return; }
      if (_mapReady) { _sendVehicles(); timer.cancel(); }
    });
  }

  Future<void> _loadModels() async {
    try {
      final carData = await rootBundle.load('assets/images/vehicles/white_car.png');
      final vespaData = await rootBundle.load('assets/images/vehicles/bike.png');
      _carBase64 = base64Encode(carData.buffer.asUint8List());
      _vespaBase64 = base64Encode(vespaData.buffer.asUint8List());
      _checkAndInjectModels();
    } catch (e) {
      debugPrint('Error loading sprites: $e');
    }
  }

  void _checkAndInjectModels() {
    if (_mapReady && _carBase64 != null && _vespaBase64 != null) {
      final cw = _iframe.contentWindow;
      if (cw == null) return;
      cw.postMessage(jsonEncode({
        'type': 'addModels',
        'carUri': 'data:image/png;base64,$_carBase64',
        'vespaUri': 'data:image/png;base64,$_vespaBase64',
      }), '*');
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _sub.cancel();
    super.dispose();
  }

  void _sendVehicles() {
    final cw = _iframe.contentWindow;
    if (cw == null) return;
    final list = widget.vehicles.where((v) => v.hasLocation).map((v) => {
      'id': v.id, 'lat': v.latitude, 'lng': v.longitude, 'heading': v.heading,
      'status': v.status.name, 'name': v.displayName, 'type': v.displayType,
    }).toList();
    cw.postMessage(jsonEncode({'type': 'updateVehicles', 'vehicles': list}), '*');
  }

  void _sendCenter() {
    final cw = _iframe.contentWindow;
    if (cw == null) return;
    
    if (widget.selectedVehicle != null) {
      final v = widget.selectedVehicle!;
      cw.postMessage(jsonEncode({'type': 'centerMap', 'lat': v.latitude, 'lng': v.longitude, 'heading': v.heading}), '*');
    } else if (widget.mapCenter != null) {
      cw.postMessage(jsonEncode({'type': 'centerMap', 'lat': widget.mapCenter!.latitude, 'lng': widget.mapCenter!.longitude, 'heading': 0}), '*');
    }
  }

  @override
  void didUpdateWidget(covariant Map3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;
    if (widget.vehicles != oldWidget.vehicles) _sendVehicles();
    if (widget.mapCenter != oldWidget.mapCenter && widget.mapCenter != null) _sendCenter();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
