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

  // Provisional figures for the solo island. The brief names these systems
  // and does not give the numbers. They are starting values so the three
  // cities can be played. They are not locked. See docs/DECISIONS.md.

  static const fastTicksPerSlowDay = 4;

  static const harborPopulation = 4200.0;
  static const harborJobs = 3800.0;
  static const harborOutput = 55.0;
  static const harborGrowth = 0.004;
  static const harborConcentration = 0.46;
  static const harborUnlockPopulation = 5000.0;

  static const ironPopulation = 2100.0;
  static const ironJobs = 1900.0;
  static const ironOutput = 70.0;
  static const ironGrowth = 0.008;
  static const ironConcentration = 0.86;
  static const ironUnlockPopulation = 2500.0;

  static const greenPopulation = 3100.0;
  static const greenJobs = 2800.0;
  static const greenOutput = 40.0;
  static const greenGrowth = 0.002;
  static const greenConcentration = 0.18;
  static const greenUnlockPopulation = 3600.0;

  static const ironPitTraffic = 72.0;
  static const ironRailTraffic = 48.0;
  static const ironCampTraffic = 22.0;
  static const greenMillTraffic = 42.0;
  static const greenRiverTraffic = 35.0;
  static const greenOrchardTraffic = 28.0;
  static const newWharfTraffic = 30.0;
  static const veinRoadTraffic = 36.0;
  static const southFieldTraffic = 24.0;

  static const proGrowthPermit = 0.85;
  static const steadyPermit = 1.0;
  static const cautiousPermit = 1.20;
  static const proGrowthPropertyTax = 0.0008;
  static const steadyPropertyTax = 0.0015;
  static const cautiousPropertyTax = 0.003;
  static const proGrowthBusinessTax = 0.05;
  static const steadyBusinessTax = 0.10;
  static const cautiousBusinessTax = 0.18;
  static const proGrowthPace = 1.35;
  static const steadyPace = 1.0;
  static const cautiousPace = 0.70;

  static const warehouseSlope = 2.4;
  static const warehouseIntercept = -40.0;
  static const warehouseCost = 8000.0;
  static const dinerPerCapita = 0.04;
  static const dinerIntercept = -30.0;
  static const dinerCost = 4000.0;
  static const siloSlope = 3.2;
  static const siloIntercept = -50.0;
  static const siloCost = 7000.0;
  static const farmSlope = 1.6;
  static const farmIntercept = -20.0;
  static const farmCost = 3000.0;
  static const houseBase = 8.0;
  static const housePerCapita = 0.012;
  static const houseCost = 6000.0;

  /// The ×18 multiple is stated for Appendix A businesses. Houses use the
  /// same multiple only as a starting value.
  static const houseIncomeMultiple = 18.0;

  static const sharesOutstanding = 1000;
  static const shareCap = 0.20;
  static const shareFee = 0.005;
  static const shareSpread = 0.01;
  static const shareImpact = 0.60;
  static const shareDrift = 0.05;
  static const shareNoise = 0.008;
  static const shareMinPrice = 1.0;
  static const shareLot = 10;
  static const traderShareCap = 0.15;
  static const investorShareCap = 0.10;

  static const shippingPerOutput = 280.0;
  static const shippingPerPerson = 6.0;
  static const shippingYield = 0.0012;
  static const bankPerPerson = 5.0;
  static const bankPerJob = 4.0;
  static const bankYield = 0.002;
  static const miningPerOutput = 420.0;
  static const miningPerPerson = 8.0;
  static const miningYield = 0.0008;
  static const coopPerOutput = 220.0;
  static const coopPerPerson = 6.0;
  static const coopYield = 0.004;

  static const islandBotMaxPlots = 6;
  static const taraAct = 0.55;
  static const vikAct = 0.40;
  static const taraBuyRise = 0.01;
  static const taraSellFall = -0.015;
  static const vikDiscount = 0.92;
  static const vikPremium = 1.12;
  static const trafficDrift = 0.08;
  static const ironFirstRumorDay = 4;
  static const greenFirstRumorDay = 5;
  static const shockDelay = 4;
  static const projectChance = 0.55;
  static const projectOutputBoost = 0.03;
  static const projectDemand = 0.05;
  static const projectMissDemand = -0.02;
  static const veinOutput = 1.30;
  static const veinConcentration = 0.05;
  static const thinOutput = 0.75;
  static const thinConcentration = 0.02;
  static const droughtFactor = 0.65;
  static const droughtDays = 8;
  static const crunchPrice = 0.88;
  static const crunchDemand = -0.12;
  static const bankScarePrice = 0.75;
  static const bankScareDemand = -0.06;
  static const ironStartingLots = 1;
  static const greenStartingLots = 1;
}
