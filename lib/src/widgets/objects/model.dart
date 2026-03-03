import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:mago_widgets/src/widgets/components/object_loader.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_controls/three_js_controls.dart';
import 'package:three_js_math/three_js_math.dart' as thmath;

class CameraInfo {
  final Vec3 position;
  final double azimuthalAngle;
  final double polarAngle;
  final double distance;

  const CameraInfo({
    required this.position,
    required this.azimuthalAngle,
    required this.polarAngle,
    required this.distance,
  });

  factory CameraInfo.fromJson(Map<String, dynamic> json) {
    return CameraInfo(
      position: Vec3(
        (json['position']?['x'] as num?)?.toDouble() ?? 0,
        (json['position']?['y'] as num?)?.toDouble() ?? 0,
        (json['position']?['z'] as num?)?.toDouble() ?? 0,
      ),
      azimuthalAngle: (json['rotation']?['x'] as num?)?.toDouble() ?? 0,
      polarAngle: (json['rotation']?['y'] as num?)?.toDouble() ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'position': {'x': position.x, 'y': position.y, 'z': position.z},
        'rotation': {'x': azimuthalAngle, 'y': polarAngle},
        'distance': distance,
      };
}

class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);
}

class MaterialInfo {
  final String id;
  final String name;
  final String? colorHex;
  final double? metalness;
  final double? roughness;

  const MaterialInfo({
    required this.id,
    required this.name,
    this.colorHex,
    this.metalness,
    this.roughness,
  });

  factory MaterialInfo.fromJson(Map<String, dynamic> json) {
    return MaterialInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      colorHex: json['color'] as String? ?? json['colorHex'] as String?,
      metalness: (json['metalness'] as num?)?.toDouble(),
      roughness: (json['roughness'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorHex,
        'metalness': metalness,
        'roughness': roughness,
      };
}

class MagoModel extends StatefulWidget {
  final String? modelUrl;

  final Map<String, double>? dimensions;

  final String? hdriAsset;

  final double hdriIntensity;
  final double hdriExposure;

  final bool showHdriBackground;

  final ValueChanged<CameraInfo>? onCameraInfoUpdate;
  final ValueChanged<MaterialInfo>? onMaterialInfoUpdate;
  final ValueChanged<MagoModelViewerState>? onViewerCreated;
  final ValueChanged<List<MaterialInfo>>? onMaterialsExtracted;

  const MagoModel({
    super.key,
    this.modelUrl,
    this.dimensions,
    this.hdriAsset,
    this.hdriIntensity = 1.4,
    this.hdriExposure = 1.4,
    this.showHdriBackground = false,
    this.onCameraInfoUpdate,
    this.onMaterialInfoUpdate,
    this.onViewerCreated,
    this.onMaterialsExtracted,
  });

  @override
  State<MagoModel> createState() => MagoModelViewerState();
}

class MagoModelViewerState extends State<MagoModel> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _disposed = false;

  three.ThreeJS? _threeJs;
  three.Object3D? _rootModel;
  OrbitControls? _controls;

  three.PMREMGenerator? _pmrem;
  three.RenderTarget? _envRT;

  double _lastW = -1;
  double _lastH = -1;

  three.Vector3 _orbitTarget = three.Vector3(0, 0, 0);

  double _camAzimuth = 0;
  double _camPolar = math.pi / 2;
  double _camDistance = 5;

  double _targetAzimuth = 0;
  double _targetPolar = math.pi / 2;
  double _targetDistance = 5;
  bool _isAnimatingCamera = false;

  double _minDistance = 0.05;
  double _maxDistance = 10.0;

  double _lastSentAzimuth = 0;
  double _lastSentPolar = 0;
  double _lastSentDistance = 0;
  bool _canSendCameraUpdate = true;
  static const double _sendThreshold = 0.02;
  static const Duration _cameraThrottleDuration = Duration(milliseconds: 50);

  double _layoutW = 0;
  double _layoutH = 0;

  @override
  void initState() {
    super.initState();
    _threeJs = three.ThreeJS(
      setup: _setupScene,
      onSetupComplete: () {},
      settings: three.Settings(
        alpha: true,
        clearAlpha: 0.0,
        clearColor: 0x000000,
        enableShadowMap: false,
      ),
    );
    widget.onViewerCreated?.call(this);
  }

  @override
  void didUpdateWidget(covariant MagoModel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelUrl != widget.modelUrl) _reloadModel();
  }

  @override
  void dispose() {
    _disposed = true;

    _controls?.dispose();
    _controls = null;

    try {
      _envRT?.dispose();
    } catch (_) {}
    _envRT = null;

    try {
      _pmrem?.dispose();
    } catch (_) {}
    _pmrem = null;

    final tj = _threeJs;
    final root = _rootModel;
    if (tj != null) {
      if (root != null) {
        try {
          tj.scene.remove(root);
        } catch (_) {}
        _disposeObject3D(root);
        _rootModel = null;
      }
      try {
        tj.dispose();
      } catch (_) {}
    }
    _threeJs = null;
    super.dispose();
  }

  bool get isReady => !_isLoading && _rootModel != null;

  List<MaterialInfo> extractMaterials() {
    final results = <MaterialInfo>[];
    _rootModel?.traverse((obj) {
      if (obj is three.Mesh && obj.material is three.MeshStandardMaterial) {
        final mat = obj.material as three.MeshStandardMaterial;
        String? hex;
        try {
          final c = mat.color;
          final r = (c.red * 255).round().clamp(0, 255);
          final g = (c.green * 255).round().clamp(0, 255);
          final b = (c.blue * 255).round().clamp(0, 255);
          hex = '#${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}';
        } catch (_) {}

        final name = mat.name.isNotEmpty
            ? mat.name
            : (obj.name.isNotEmpty ? obj.name : 'Material');
        final id = obj.name.isNotEmpty ? obj.name : mat.name;

        results.add(MaterialInfo(
          id: id,
          name: name,
          colorHex: hex,
          metalness: mat.metalness,
          roughness: mat.roughness,
        ));
      }
    });
    return results;
  }

  void updateTransform(Map<String, dynamic> transform) {
    _targetAzimuth =
        (transform['rotation']?['x'] as num?)?.toDouble() ?? _targetAzimuth;
    _targetPolar =
        (transform['rotation']?['y'] as num?)?.toDouble() ?? _targetPolar;
    _targetDistance =
        ((transform['distance'] as num?)?.toDouble() ?? _targetDistance)
            .clamp(_minDistance, _maxDistance);
    _isAnimatingCamera = true;
  }

  void updateMaterial(MaterialInfo material) {
    if (!isReady || _rootModel == null) return;
    _applyMaterialUpdate(
      material.id,
      material.colorHex,
      material.metalness,
      material.roughness,
    );
  }

  void setAutoRotate(bool enabled, [double speed = 1.0]) {
    _controls?.autoRotate = enabled;
    _controls?.autoRotateSpeed = speed;
  }

  void cleanup() {
    final tj = _threeJs;
    if (tj == null || _rootModel == null) return;
    try {
      tj.scene.remove(_rootModel!);
    } catch (_) {}
    _disposeObject3D(_rootModel!);
    _rootModel = null;
  }

  @override
  Widget build(BuildContext context) {
    final tj = _threeJs;
    return LayoutBuilder(
      builder: (context, constraints) {
        final newW = constraints.maxWidth;
        final newH = constraints.maxHeight;
        if (newW != _layoutW || newH != _layoutH) {
          _layoutW = newW;
          _layoutH = newH;
          if (tj != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_disposed && _threeJs != null) {
                _syncRenderer(_threeJs!);
              }
            });
          }
        }
        return ClipRect(
          child: Stack(
            children: [
              if (tj != null)
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(child: tj.build()),
                  ),
                ),
              if (_isLoading)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: MagoObjectLoader(),
                  ),
                ),
              if (_errorMessage != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setupScene() async {
    final tj = _threeJs;
    if (tj == null) return;

    try {
      tj.scene = three.Scene();
      tj.scene.background = null;

      tj.camera = three.PerspectiveCamera(45, 1.0, 0.01, 500);
      tj.camera.position.setValues(0, 0, 5);

      if (widget.hdriAsset != null) {
        await _loadHdriEnvironment(tj);
      }

      tj.scene.add(three.AmbientLight(0xffffff, 0.15));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _disposed) return;
        _controls?.dispose();
        _controls = OrbitControls(tj.camera, tj.globalKey)
          ..enableDamping = false
          ..enablePan = false
          ..minDistance = _minDistance
          ..maxDistance = _maxDistance;
        _controls!.target.setValues(
          _orbitTarget.x,
          _orbitTarget.y,
          _orbitTarget.z,
        );
        _controls!.update();
        _syncRenderer(tj);
      });

      await _reloadModel(initial: true);

      tj.addAnimationEvent(_onFrame);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      if (widget.onMaterialsExtracted != null && _rootModel != null) {
        widget.onMaterialsExtracted!(extractMaterials());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize 3D viewer: $e';
      });
    }
  }

  Future<void> _loadHdriEnvironment(three.ThreeJS tj) async {
    final renderer = tj.renderer;
    if (renderer == null) return;

    try {
      renderer.toneMapping = three.ACESFilmicToneMapping;
      renderer.toneMappingExposure = widget.hdriExposure;
    } catch (_) {}

    try {
      renderer.outputColorSpace = three.SRGBColorSpace;
    } catch (_) {
      try {
        renderer.outputEncoding = three.sRGBEncoding;
      } catch (_) {}
    }

    try {
      _envRT?.dispose();
    } catch (_) {}
    _envRT = null;

    _pmrem ??= three.PMREMGenerator(renderer);
    try {
      _pmrem!.compileEquirectangularShader();
    } catch (_) {}

    final data = await rootBundle.load(widget.hdriAsset!);
    final bytes = data.buffer.asUint8List();

    final rgbe = three.RGBELoader();
    final hdrTex = await rgbe.fromBytes(bytes);
    if (hdrTex == null) return;

    try {
      hdrTex.mapping = three.EquirectangularReflectionMapping;
    } catch (_) {}

    final rt = _pmrem!.fromEquirectangular(hdrTex);
    _envRT = rt;

    tj.scene.environment = rt.texture;
    try {
      tj.scene.environmentIntensity = widget.hdriIntensity;
    } catch (_) {}

    if (widget.showHdriBackground) {
      tj.scene.background = rt.texture;
      try {
        tj.scene.backgroundIntensity = widget.hdriIntensity;
      } catch (_) {}
    }

    _rootModel?.traverse((obj) {
      if (obj is three.Mesh && obj.material is three.MeshStandardMaterial) {
        final m = obj.material as three.MeshStandardMaterial;
        try {
          m.envMapIntensity = widget.hdriIntensity;
          m.needsUpdate = true;
        } catch (_) {}
      }
    });

    try {
      hdrTex.dispose();
    } catch (_) {}
  }

  Future<void> _reloadModel({bool initial = false}) async {
    final tj = _threeJs;
    if (tj == null) return;

    if (!initial && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    if (_rootModel != null) {
      try {
        tj.scene.remove(_rootModel!);
      } catch (_) {}
      _disposeObject3D(_rootModel!);
      _rootModel = null;
    }

    try {
      final url = widget.modelUrl;
      if (url != null && url.isNotEmpty) {
        await _loadModelFromUrl(tj, url);
      } else {
        _createFallbackCube(tj);
      }

      final model = _rootModel;
      if (model != null) {
        const targetRadius = 1.0;
        _normalizeModelToUnit(model, targetRadius: targetRadius);
        _orbitTarget = three.Vector3(0, 0, 0);

        final cam = tj.camera;
        if (cam is three.PerspectiveCamera) {
          final dist =
              _cameraDistanceForRadius(cam, targetRadius, padding: 1.25);
          _camDistance = dist;
          _targetDistance = dist;
          _camAzimuth = _camAzimuth.isFinite ? _camAzimuth : 0;
          _camPolar =
              (_camPolar.isFinite && _camPolar > 0) ? _camPolar : (math.pi / 2);
          _targetAzimuth = _camAzimuth;
          _targetPolar = _camPolar;
          _applySphericalCamera(tj);
          _controls?.target.setValues(0, 0, 0);
          _controls?.update();
        }
      }

      _updateOrbitTargetFromModel(_rootModel);
      _applySphericalCamera(tj);
      tj.camera.lookAt(_orbitTarget);
      _controls?.target.setValues(
        _orbitTarget.x,
        _orbitTarget.y,
        _orbitTarget.z,
      );
      _controls?.update();
    } catch (e) {
      _createFallbackCube(tj);
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load 3D model:\n$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _syncRenderer(tj);

        if (!initial &&
            widget.onMaterialsExtracted != null &&
            _rootModel != null) {
          widget.onMaterialsExtracted!(extractMaterials());
        }
      }
    }
  }

  Future<void> _loadModelFromUrl(three.ThreeJS tj, String url) async {
    final loader = three.GLTFLoader(flipY: true);
    final gltfData = await loader.fromNetwork(Uri.parse(url));
    if (gltfData == null) throw Exception('GLTF data is null');
    _rootModel = gltfData.scene;
    tj.scene.add(_rootModel!);
  }

  void _createFallbackCube(three.ThreeJS tj) {
    final geometry = three.BoxGeometry(1, 1, 1);
    final material = three.MeshStandardMaterial({
      three.MaterialProperty.color: 0x00ff00,
      three.MaterialProperty.metalness: 0.3,
      three.MaterialProperty.roughness: 0.4,
    });
    _rootModel = three.Mesh(geometry, material);
    tj.scene.add(_rootModel!);
  }

  double _normalizeModelToUnit(three.Object3D model,
      {double targetRadius = 1.0}) {
    final box = thmath.BoundingBox()..setFromObject(model, true);
    final center = box.getCenter(thmath.Vector3.zero());
    model.position.sub(three.Vector3(center.x, center.y, center.z));

    final box2 = thmath.BoundingBox()..setFromObject(model, true);
    final sphere = thmath.BoundingSphere();
    box2.getBoundingSphere(sphere);

    final radius =
        (sphere.radius.isFinite && sphere.radius > 0) ? sphere.radius : 1.0;
    final s = targetRadius / radius;
    model.scale.setValues(s, s, s);
    return targetRadius;
  }

  double _cameraDistanceForRadius(
    three.PerspectiveCamera cam,
    double radius, {
    double padding = 1.2,
  }) {
    final fovRad = cam.fov * math.pi / 180.0;
    return (radius / math.sin(fovRad / 2.0)) * padding;
  }

  void _updateOrbitTargetFromModel(three.Object3D? model) {
    if (model == null) {
      _orbitTarget = three.Vector3(0, 0, 0);
      _camDistance = 5;
      _targetDistance = 5;
      return;
    }
    try {
      final box = thmath.BoundingBox()..setFromObject(model, true);
      final c = box.getCenter(thmath.Vector3.zero());
      _orbitTarget = three.Vector3(c.x, c.y, c.z);

      final sphere = thmath.BoundingSphere();
      box.getBoundingSphere(sphere);
      final r = (sphere.radius > 0) ? sphere.radius : 1.0;
      final suggested = (r * 2.5).clamp(2.0, 200.0);

      _camDistance = suggested;
      _targetDistance = suggested;
      _camAzimuth = _camAzimuth.isFinite ? _camAzimuth : 0;
      _camPolar = _camPolar.isFinite ? _camPolar : (math.pi / 2);
      _targetAzimuth = _camAzimuth;
      _targetPolar = _camPolar;
    } catch (_) {
      _orbitTarget = three.Vector3(0, 0, 0);
    }
  }

  void _syncRenderer(three.ThreeJS tj) {
    final w = widget.dimensions?['width'] ?? (_layoutW > 0 ? _layoutW : 1280.0);
    final h = widget.dimensions?['height'] ?? (_layoutH > 0 ? _layoutH : 720.0);
    final dpr = MediaQuery.of(context).devicePixelRatio;

    try {
      tj.renderer?.setPixelRatio(dpr);
    } catch (_) {}
    try {
      tj.renderer?.setSize(w, h, false);
      tj.renderer?.setScissorTest(false);
    } catch (_) {}

    final cam = tj.camera;
    if (cam is three.PerspectiveCamera) {
      cam.aspect = w / h;
      cam.updateProjectionMatrix();
    }

    _lastW = w;
    _lastH = h;
  }

  void _applyMaterialUpdate(
    String materialId,
    String? colorHex,
    double? metalness,
    double? roughness,
  ) {
    _rootModel?.traverse((obj) {
      if (obj is three.Mesh) {
        final mat = obj.material;
        if (mat is three.MeshStandardMaterial &&
            (obj.name == materialId || mat.name == materialId)) {
          if (colorHex != null) {
            final v = int.tryParse(colorHex.replaceFirst('#', ''), radix: 16);
            if (v != null) mat.color = three.Color.fromHex32(v);
          }
          if (metalness != null) mat.metalness = metalness;
          if (roughness != null) mat.roughness = roughness;
          mat.needsUpdate = true;
        }
      }
    });
  }

  void _applySphericalCamera(three.ThreeJS tj) {
    final x = _camDistance * math.sin(_camPolar) * math.cos(_camAzimuth) +
        _orbitTarget.x;
    final y = _camDistance * math.cos(_camPolar) + _orbitTarget.y;
    final z = _camDistance * math.sin(_camPolar) * math.sin(_camAzimuth) +
        _orbitTarget.z;

    tj.camera.position.setValues(x, y, z);
    tj.camera.lookAt(_orbitTarget);

    final cam = tj.camera;
    if (cam is three.PerspectiveCamera) {
      cam.near = math.max(_camDistance / 500.0, 0.001);
      cam.far = math.max(_camDistance * 500.0, 100.0);
      cam.updateProjectionMatrix();
    }
  }

  void _animateCamera(three.ThreeJS tj) {
    const lerp = 0.25;
    _camAzimuth += (_targetAzimuth - _camAzimuth) * lerp;
    _camPolar += (_targetPolar - _camPolar) * lerp;
    _camDistance += (_targetDistance - _camDistance) * lerp;
    _applySphericalCamera(tj);

    const done = 0.005;
    if ((_targetAzimuth - _camAzimuth).abs() < done &&
        (_targetPolar - _camPolar).abs() < done &&
        (_targetDistance - _camDistance).abs() < done) {
      _camAzimuth = _targetAzimuth;
      _camPolar = _targetPolar;
      _camDistance = _targetDistance;
      _isAnimatingCamera = false;
    }
  }

  void _sendCameraInfo(three.ThreeJS tj) {
    if (_isAnimatingCamera) return;
    final cb = widget.onCameraInfoUpdate;
    if (cb == null) return;

    final pos = tj.camera.position;
    final ox = pos.x - _orbitTarget.x;
    final oy = pos.y - _orbitTarget.y;
    final oz = pos.z - _orbitTarget.z;
    final r = math.sqrt(ox * ox + oy * oy + oz * oz);
    if (r <= 0) return;

    final polar = math.acos(oy / r);
    final azimuth = math.atan2(oz, ox);

    if ((azimuth - _lastSentAzimuth).abs() < _sendThreshold &&
        (polar - _lastSentPolar).abs() < _sendThreshold &&
        (r - _lastSentDistance).abs() < _sendThreshold) {
      return;
    }

    _lastSentAzimuth = azimuth;
    _lastSentPolar = polar;
    _lastSentDistance = r;

    _canSendCameraUpdate = false;
    Future.delayed(_cameraThrottleDuration, () {
      if (mounted && !_disposed) _canSendCameraUpdate = true;
    });

    cb(CameraInfo(
      position: Vec3(pos.x.toDouble(), pos.y.toDouble(), pos.z.toDouble()),
      azimuthalAngle: azimuth,
      polarAngle: polar,
      distance: r,
    ));
  }

  void _onFrame(double dt) {
    if (_disposed || !mounted) return;
    final tj = _threeJs;
    if (tj == null) return;

    final w = _layoutW;
    final h = _layoutH;
    if (w > 0 && h > 0 && (w != _lastW || h != _lastH)) {
      _syncRenderer(tj);
      if (kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_threeJs != null && mounted && !_disposed) {
            _syncRenderer(_threeJs!);
          }
        });
      }
    }

    _controls?.update();

    if (_isAnimatingCamera) _animateCamera(tj);
    if (_canSendCameraUpdate) _sendCameraInfo(tj);
  }

  void _disposeObject3D(three.Object3D obj) {
    for (final child in obj.children.toList()) {
      _disposeObject3D(child);
    }
    if (obj is three.Mesh) {
      try {
        obj.geometry?.dispose();
      } catch (_) {}
      try {
        obj.material?.dispose();
      } catch (_) {}
    }
    obj.children.clear();
  }
}
