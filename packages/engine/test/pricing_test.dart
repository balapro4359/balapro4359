import 'package:holdings_engine/holdings_engine.dart';
import 'package:test/test.dart';

void main() {
  test('land prices that are not halfway round to the nearest ten', () {
    final cases = <int, int>{
      0: 900,
      6: 1150,
      22: 1820,
      42: 2660,
      55: 3210,
      72: 3920,
      95: 4890,
      100: 5100,
    };
    cases.forEach((traffic, price) {
      expect(
        landPrice(traffic: traffic.toDouble(), multiplier: 1),
        price,
        reason: 'traffic $traffic',
      );
    });
  });

  test('car wash and parking income change sign at the quiet-street line', () {
    expect(
      businessIncome(
        building: BuildingType.carWash,
        traffic: 23,
        openForBusiness: true,
      ),
      closeTo(-3.5, 1e-9),
    );
    expect(
      businessIncome(
        building: BuildingType.carWash,
        traffic: 24,
        openForBusiness: true,
      ),
      closeTo(2, 1e-9),
    );
    expect(
      businessIncome(
        building: BuildingType.parking,
        traffic: 12,
        openForBusiness: true,
      ),
      closeTo(-1, 1e-9),
    );
    expect(
      businessIncome(
        building: BuildingType.parking,
        traffic: 13,
        openForBusiness: true,
      ),
      closeTo(1, 1e-9),
    );
  });

  test('a closed building earns nothing', () {
    expect(
      businessIncome(
        building: BuildingType.carWash,
        traffic: 80,
        openForBusiness: false,
      ),
      0,
    );
  });

  test('parking at traffic 55 prices to 4740 and sells for 4503', () {
    const income = 85.0;
    expect(
      businessIncome(
        building: BuildingType.parking,
        traffic: 55,
        openForBusiness: true,
      ),
      income,
    );
    expect(
      buildingValue(building: BuildingType.parking, dailyIncome: income),
      1530,
    );
    final value = plotValue(
      traffic: 55,
      multiplier: 1,
      building: BuildingType.parking,
      dailyIncome: income,
    );
    expect(value, 4740);
    expect(saleProceeds(value), 4503);
  });

  test('an empty plot is worth its land price', () {
    expect(
      plotValue(
        traffic: 55,
        multiplier: 1,
        building: null,
        dailyIncome: 0,
      ),
      3210,
    );
  });

  test('negative income does not pull building value under the cost floor', () {
    expect(
      buildingValue(building: BuildingType.carWash, dailyIncome: -130),
      2000,
    );
    expect(
      buildingValue(building: BuildingType.parking, dailyIncome: -25),
      1000,
    );
  });

  test('street update matches the worked rows', () {
    final calm = updateStreet(multiplier: 1, demand: 0, noise: 0);
    expect(calm.multiplier, 1);
    expect(calm.demand, 0);

    final bought = updateStreet(multiplier: 1, demand: 0.03, noise: 0);
    expect(bought.multiplier, closeTo(1.0291, 1e-9));
    expect(bought.demand, closeTo(0.0135, 1e-9));

    final sold = updateStreet(multiplier: 1, demand: -0.03, noise: 0);
    expect(sold.multiplier, closeTo(0.9709, 1e-9));
    expect(sold.demand, closeTo(-0.0135, 1e-9));

    final capped = updateStreet(multiplier: 2.2, demand: 0.5, noise: 0.022);
    expect(capped.multiplier, 2.2);
    expect(capped.demand, closeTo(0.225, 1e-9));
  });

  test('extra city drivers do not change car wash or parking income', () {
    expect(
      businessIncome(
        building: BuildingType.carWash,
        traffic: 55,
        openForBusiness: true,
        output: 70,
        population: 4200,
        employment: 0.5,
      ),
      closeTo(172.5, 1e-9),
    );
    expect(
      businessIncome(
        building: BuildingType.parking,
        traffic: 55,
        openForBusiness: true,
        output: 70,
        population: 4200,
      ),
      closeTo(85, 1e-9),
    );
  });

  test('a house is valued from its rent', () {
    expect(
      buildingValue(building: BuildingType.house, dailyIncome: 50),
      closeTo(50 * Tuning.houseIncomeMultiple, 1e-9),
    );
  });

  test('a rise of exactly 2 percent is not over 2 percent', () {
    expect(0.02 > Tuning.ritaBuyRise, isFalse);
    expect(0.0201 > Tuning.ritaBuyRise, isTrue);
    expect(percentChange([1, 1.03], 1)! > Tuning.ritaBuyRise, isTrue);
  });
}
