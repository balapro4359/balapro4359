/// Numbers Appendix A states. Open questions are not given a value here.
abstract final class Tuning {
  static const soloSeasonDays = 40;
  static const startingCash = 12000.0;
  static const autoDayInterval = Duration(milliseconds: 1500);

  static const plotsPerStreet = 5;
  static const trafficStartJitter = 13;
  static const trafficStartMin = 6.0;
  static const trafficStartMax = 95.0;
  static const trafficMin = 0.0;
  static const trafficMax = 100.0;
  static const carsPerTraffic = 12.0;
  static const carsNoise = 0.09;

  static const landIntercept = 900.0;
  static const landPerTraffic = 42.0;
  static const moneyQuantum = 10;

  static const carWashSlope = 5.5;
  static const carWashIntercept = -130.0;
  static const parkingSlope = 2.0;
  static const parkingIntercept = -25.0;
  static const buildingCostFraction = 0.40;
  static const buildingIncomeMultiple = 18.0;
  static const carWashCost = 5000.0;
  static const parkingCost = 2500.0;

  static const saleProceeds = 0.95;
  static const saleFee = 0.05;

  static const buyDemand = 0.03;
  static const sellDemand = -0.03;
  static const multiplierStart = 1.0;
  static const multiplierNoise = 0.022;
  static const multiplierPull = 0.03;
  static const multiplierMin = 0.5;
  static const multiplierMax = 2.2;
  static const demandDecay = 0.45;

  static const firstRumorDay = 3;
  static const announceGoodDemand = 0.07;
  static const announceBadDemand = -0.06;
  static const happenGoodDemand = 0.05;
  static const happenBadDemand = -0.10;
  static const missGoodDemand = -0.10;
  static const missBadDemand = 0.05;
  static const permanentBaseMin = 3.0;
  static const permanentBaseMax = 98.0;
  static const permanentJitter = 3;

  static const botMaxPlots = 3;
  static const botBuyBuffer = 300.0;
  static const botBuildBuffer = 500.0;
  static const ritaAct = 0.50;
  static const omarAct = 0.45;
  static const meiAct = 0.40;
  static const dexAct = 0.40;
  static const ritaBuyRise = 0.02;
  static const ritaSellFall = -0.05;
  static const omarCarWashTraffic = 48.0;
  static const omarSellIncome = 15.0;
  static const startingParkingLots = 2;
}
