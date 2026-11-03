// Unit factors copied from ios/ConvCalc/Core/ConverterCore.swift.
const u = (label, name, factor) => ({ label, name, to: (v) => v * factor, from: (v) => v / factor });
export const TOOLS = {
  length: { units: [u("mm","Millimeter",.001),u("cm","Centimeter",.01),u("m","Meter",1),u("km","Kilometer",1000),u("in","Inch",.0254),u("ft","Foot",.3048),u("yd","Yard",.9144),u("mi","Mile",1609.344)] },
  area: { units: [u("m²","Square Meter",1),u("ft²","Square Foot",.092903),u("km²","Square Kilometer",1e6),u("mi²","Square Mile",2589988.11),u("acres","Acre",4046.8564),u("ha","Hectare",10000)] },
  mass: { units: [u("mg","Milligram",.000001),u("g","Gram",.001),u("kg","Kilogram",1),u("dr","Dram",.001771845195),u("oz","Ounce",.028349523),u("lb","Pound",.45359237),u("st","Stone",6.35029318),u("slug","Slug",14.593903),u("short tn","Short Ton",907.18474),u("long tn","Long Ton",1016.0469088),u("t","Metric Ton",1000)] },
  volume: { units: [u("ml","Milliliter",.001),u("L","Liter",1),u("gal","Gallon",3.785411784),u("qt","Quart",.946352946),u("pt","Pint",.473176473),u("cup","Cup",.2365882365),u("fl oz","Fluid Ounce",.029573529)] },
  speed: { units: [u("m/s","Meter per Second",1),u("km/h","Kilometer per Hour",1/3.6),u("mph","Mile per Hour",.44704),u("knots","Knot",.514444)] },
  pressure: { units: [u("Pa","Pascal",1),u("kPa","Kilopascal",1000),u("bar","Bar",100000),u("atm","Atmosphere",101325),u("PSI","Pound per Sq Inch",6894.757293168),u("inHg","Inch of Mercury",3386.389),u("Torr","Torr",133.3223684211)] },
  power: { units: [u("W","Watt",1),u("kW","Kilowatt",1000),u("hp","Horsepower",745.69987158),u("BTU/min","BTU per Minute",17.584264)] },
  temperature: { units: [{label:"°C",name:"Celsius",to:v=>v,from:v=>v},{label:"°F",name:"Fahrenheit",to:v=>(v-32)*5/9,from:v=>v*9/5+32},{label:"K",name:"Kelvin",to:v=>v-273.15,from:v=>v+273.15}] },
  angle: { units: [u("rad","Radian",1),u("mrad","Milliradian",.001),u("µrad","Microradian",.000001),u("°","Degree",Math.PI/180),u("arcmin","Arcminute",Math.PI/10800),u("arcsec","Arcsecond",Math.PI/648000),u("mas","Milliarcsecond",Math.PI/648000000),u("µas","Microarcsecond",Math.PI/648000000000)] },
  energy: { units: [u("J","Joule",1),u("kJ","Kilojoule",1000),u("cal","Calorie",4.184),u("kcal","Kilocalorie",4184),u("BTU","British Thermal Unit",1055.06),u("kWh","Kilowatt-Hour",3600000),u("erg","Erg",1e-7),u("ft·lbf","Foot-Pound",1.3558179483),u("N·m","Newton-Meter",1)] },
  force: { units: [u("N","Newton",1),u("kgf","Kilogram-Force",9.80665),u("lbf","Pound-Force",4.4482216152605),u("pdl","Poundal",.138254954376),u("dyn","Dyne",.00001)] },
  fuel: { units: [u("km/L","Kilometer per Liter",1),u("mpg","Mile per Gallon",.425143707),{label:"L/100km",name:"Liter per 100km",to:v=>100/v,from:v=>100/v},{label:"gal/100mi",name:"Gallon per 100mi",to:v=>42.51437/v,from:v=>42.51437/v}] },
  time: { units: [u("ms","Millisecond",.001),u("s","Second",1),u("min","Minute",60),u("hr","Hour",3600),u("day","Day",86400),u("week","Week",604800),u("year","Year",31557600)] },
  data: { units: [u("B","Byte",1),u("KB","Kilobyte",1024),u("MB","Megabyte",1048576),u("GB","Gigabyte",1073741824),u("TB","Terabyte",1099511627776),u("PB","Petabyte",1125899906842624)] },
};
export const GRID = [
  ["currency","Currency","dollar-sign"],["length","Length","ruler"],["area","Area","grid-2x2"],["mass","Mass","scale"],
  ["volume","Volume","test-tubes"],["speed","Speed","gauge"],["pressure","Pressure","arrow-down-to-line"],["power","Power","nut"],
  ["temperature","Temp","thermometer"],["angle","Angle","triangle"],["energy","Energy","flame"],["force","Force","arrow-down-up"],
  ["fuel","Fuel","fuel"],["time","Time","clock"],["data","Data","hard-drive"],["age","Age","cake"],
  ["bmi","BMI","heart"],["date","Date","calendar"],["discount","Discount","tag"],["loan","Loan","landmark"],
];

export const FORM_TOOLS = ["age", "bmi", "date", "discount", "loan"];
export const UNIT_TOOLS = Object.keys(TOOLS);
