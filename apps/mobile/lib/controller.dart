import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:holdings_engine/holdings_engine.dart';

class GameController extends ChangeNotifier {
  GameController({int? seed}) : _seed = seed {
    _open();
  }

  final int? _seed;
  late HoldingsGame game;
  int tab = 0;
  String? selectedPlotId;
  bool auto = false;
  Timer? _auto;
  String? notice;
  int noticeId = 0;

  void _open() {
    game = HoldingsGame(seed: _seed ?? DateTime.now().millisecondsSinceEpoch);
    selectedPlotId = null;
    auto = false;
    notice = null;
  }

  void showTab(int index) {
    if (tab == index) return;
    tab = index;
    notifyListeners();
  }

  void selectPlot(String? id) {
    selectedPlotId = id;
    notifyListeners();
  }

  void buySelected() => _act((id) => game.buy('you', id));

  void buildSelected(BuildingType type) => _act((id) => game.build('you', id, type));

  void sellSelected() => _act((id) => game.sell('you', id));

  void _act(ActionResult Function(String id) run) {
    final id = selectedPlotId;
    if (id == null) return;
    final result = run(id);
    if (!result.ok && result.reason != null) {
      notice = result.reason;
      noticeId += 1;
    }
    notifyListeners();
  }

  void nextDay() {
    if (game.finished) return;
    game.nextDay();
    if (game.finished) {
      auto = false;
      _auto?.cancel();
      tab = 0;
    }
    notifyListeners();
  }

  void toggleAuto() {
    auto = !auto;
    _auto?.cancel();
    if (auto && !game.finished) {
      _auto = Timer.periodic(Tuning.autoDayInterval, (_) => nextDay());
    }
    notifyListeners();
  }

  void playAgain() {
    _auto?.cancel();
    _open();
    tab = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }
}
