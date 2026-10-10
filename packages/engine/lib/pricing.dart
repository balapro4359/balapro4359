import 'tuning.dart';

enum BuildingType { carWash, parking, warehouse, diner, silo, farmStand, house }

/// Half-away-from-zero to the nearest $10.
///
/// Halfway cases are still an open question. This is the provisional rule
/// the solo app uses so prices can be shown. Non-halfway values match
/// Appendix A either way.
int roundToNearest10(num raw) {
  final value = raw.toDouble();
  final negative = value.isNegative;
  final units = value.abs() / Tuning.moneyQuantum;
  final whole = units.floor();
  final fraction = units - whole;
  final rounded = fraction >= 0.5 ? whole + 1 : whole;
  final money = rounded * Tuning.moneyQuantum;
  return negative ? -money : money;
}

double clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

int landPrice({required double traffic, required double multiplier}) {
  return roundToNearest10(
    (Tuning.landIntercept + traffic * Tuning.landPerTraffic) * multiplier,
  );
}

double businessIncome({
  required BuildingType? building,
  required double traffic,
  required bool openForBusiness,
  double output = 0,
  double population = 0,
  double employment = 1,
}) {
  if (building == null || !openForBusiness) return 0;
  return switch (building) {
    BuildingType.carWash =>
      traffic * Tuning.carWashSlope + Tuning.carWashIntercept,
    BuildingType.parking =>
      traffic * Tuning.parkingSlope + Tuning.parkingIntercept,
    BuildingType.warehouse =>
      output * Tuning.warehouseSlope + Tuning.warehouseIntercept,
    BuildingType.diner =>
      population * Tuning.dinerPerCapita + Tuning.dinerIntercept,
    BuildingType.silo => output * Tuning.siloSlope + Tuning.siloIntercept,
    BuildingType.farmStand => output * Tuning.farmSlope + Tuning.farmIntercept,
    BuildingType.house =>
      Tuning.houseBase + population * Tuning.housePerCapita * employment,
  };
}

double buildingCost(BuildingType building) {
  return switch (building) {
    BuildingType.carWash => Tuning.carWashCost,
    BuildingType.parking => Tuning.parkingCost,
    BuildingType.warehouse => Tuning.warehouseCost,
    BuildingType.diner => Tuning.dinerCost,
    BuildingType.silo => Tuning.siloCost,
    BuildingType.farmStand => Tuning.farmCost,
    BuildingType.house => Tuning.houseCost,
  };
}

double buildingValue({
  required BuildingType? building,
  required double dailyIncome,
}) {
  if (building == null) return 0;
  if (building == BuildingType.house) {
    return dailyIncome * Tuning.houseIncomeMultiple;
  }
  final floor = Tuning.buildingCostFraction * buildingCost(building);
  final fromIncome = dailyIncome * Tuning.buildingIncomeMultiple;
  return floor > fromIncome ? floor : fromIncome;
}

int plotValue({
  required double traffic,
  required double multiplier,
  required BuildingType? building,
  required double dailyIncome,
}) {
  return roundToNearest10(
    landPrice(traffic: traffic, multiplier: multiplier) +
        buildingValue(building: building, dailyIncome: dailyIncome),
  );
}

double saleProceeds(int value) => value * Tuning.saleProceeds;

/// `(now / then) - 1`, or null when there is no earlier point.
double? percentChange(List<double> history, int daysBack) {
  if (daysBack <= 0 || history.length <= daysBack) return null;
  final then = history[history.length - 1 - daysBack];
  if (then == 0) return null;
  return history.last / then - 1;
}

class StreetTick {
  const StreetTick(this.multiplier, this.demand);
  final double multiplier;
  final double demand;
}

/// Daily crowd update. Noise is passed in so the draw stays outside the rule.
StreetTick updateStreet({
  required double multiplier,
  required double demand,
  required double noise,
}) {
  var next = multiplier * (1 + demand + noise);
  next = next + Tuning.multiplierPull * (1 - next);
  next = clampDouble(next, Tuning.multiplierMin, Tuning.multiplierMax);
  return StreetTick(next, demand * Tuning.demandDecay);
}
