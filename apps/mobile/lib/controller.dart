import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:holdings_engine/holdings_engine.dart';

class GameController extends ChangeNotifier {
  GameController({int? seed}) : _seed = seed {
    _open();
  }

  final int? _seed;
  late IslandGame game;
  int tab = 0;
  String cityId = 'harborview';
  String? selectedPlotId;
  bool auto = false;
  Timer? _auto;
  String? notice;
  int noticeId = 0;

  void _open() {
    game = IslandGame(seed: _seed ?? DateTime.now().millisecondsSinceEpoch);
    cityId = 'harborview';
    selectedPlotId = null;
    auto = false;
    notice = null;
  }

  void showTab(int index) {
    if (tab == index) return;
    tab = index;
    notifyListeners();
  }

  void openCity(String id) {
    cityId = id;
    selectedPlotId = null;
    tab = 2;
    notifyListeners();
  }

  void selectPlot(String? id) {
    selectedPlotId = id;
    notifyListeners();
  }

  void buySelected() => _act((id) => game.buy('you', id));

  void buildSelected(BuildingType type) =>
      _act((id) => game.build('you', id, type));

  void sellSelected() => _act((id) => game.sell('you', id));

  void orderShares(String companyId, {required bool buy}) {
    final held = game.sharesHeld('you', companyId);
    final shares = buy
        ? Tuning.shareLot
        : (held < Tuning.shareLot ? held : Tuning.shareLot);
    if (shares <= 0) return;
    final result =
        game.placeShareOrder('you', companyId, buy: buy, shares: shares);
    if (!result.ok && result.reason != null) {
      notice = result.reason;
      noticeId += 1;
    }
    notifyListeners();
  }

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

  void nextTick() {
    if (game.finished) return;
    game.next();
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
      _auto = Timer.periodic(Tuning.autoDayInterval, (_) => nextTick());
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
