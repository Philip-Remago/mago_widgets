import 'package:flutter/foundation.dart';

class MagoDrawerController extends ChangeNotifier {
  double _value = 0.0;
  bool _hidden = false;

  double get value => _value;

  bool get isOpen => _value >= 1.0;

  bool get isClosed => _value <= 0.0;

  bool get isHidden => _hidden;

  VoidCallback? _onOpen;
  VoidCallback? _onClose;
  VoidCallback? _onToggle;
  void Function(double target)? _onAnimateTo;

  void open() {
    _onOpen?.call();
  }

  void close() {
    _onClose?.call();
  }

  void toggle() {
    _onToggle?.call();
  }

  void animateTo(double target) {
    _onAnimateTo?.call(target);
  }

  void hide() {
    if (!_hidden) {
      _hidden = true;
      notifyListeners();
    }
    _onClose?.call();
  }

  void show() {
    if (_hidden) {
      _hidden = false;
      notifyListeners();
    }
    _onOpen?.call();
  }

  @internal
  void updateValue(double newValue) {
    if (_value != newValue) {
      _value = newValue;
      notifyListeners();
    }
  }

  @internal
  void attach({
    required VoidCallback onOpen,
    required VoidCallback onClose,
    required VoidCallback onToggle,
    required void Function(double target) onAnimateTo,
  }) {
    _onOpen = onOpen;
    _onClose = onClose;
    _onToggle = onToggle;
    _onAnimateTo = onAnimateTo;
  }

  @internal
  void detach() {
    _onOpen = null;
    _onClose = null;
    _onToggle = null;
    _onAnimateTo = null;
  }
}
