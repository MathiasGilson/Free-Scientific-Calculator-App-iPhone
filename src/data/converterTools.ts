export type UnitDef = {
    label: string
    name: string
    toBase: (v: number) => number
    fromBase: (v: number) => number
}

export type ConverterTool = {
    key: string
    label: string
    icon: string
    type: "unit" | "calculator"
    units?: UnitDef[]
    fields?: string[]
}

const linear = (factor: number): Pick<UnitDef, "toBase" | "fromBase"> => ({
    toBase: (v) => v * factor,
    fromBase: (v) => v / factor,
})

export const converterTools: ConverterTool[] = [
    {
        key: "currency",
        label: "Currency",
        icon: "dollar-sign",
        type: "calculator",
    },
    {
        key: "length",
        label: "Length",
        icon: "ruler",
        type: "unit",
        units: [
            { label: "mm", name: "Millimeter", ...linear(0.001) },
            { label: "cm", name: "Centimeter", ...linear(0.01) },
            { label: "m", name: "Meter", ...linear(1) },
            { label: "km", name: "Kilometer", ...linear(1000) },
            { label: "in", name: "Inch", ...linear(0.0254) },
            { label: "ft", name: "Foot", ...linear(0.3048) },
            { label: "yd", name: "Yard", ...linear(0.9144) },
            { label: "mi", name: "Mile", ...linear(1609.344) },
        ],
    },
    {
        key: "area",
        label: "Area",
        icon: "grid-2x2",
        type: "unit",
        units: [
            { label: "m\u00B2", name: "Square Meter", ...linear(1) },
            { label: "ft\u00B2", name: "Square Foot", ...linear(0.092903) },
            { label: "km\u00B2", name: "Square Kilometer", ...linear(1e6) },
            { label: "mi\u00B2", name: "Square Mile", ...linear(2589988.11) },
            { label: "acres", name: "Acre", ...linear(4046.8564) },
            { label: "ha", name: "Hectare", ...linear(10000) },
        ],
    },
    {
        key: "mass",
        label: "Mass",
        icon: "weight",
        type: "unit",
        units: [
            { label: "mg", name: "Milligram", ...linear(0.000001) },
            { label: "g", name: "Gram", ...linear(0.001) },
            { label: "kg", name: "Kilogram", ...linear(1) },
            { label: "dr", name: "Dram", ...linear(0.001771845195) },
            { label: "oz", name: "Ounce", ...linear(0.028349523) },
            { label: "lb", name: "Pound", ...linear(0.45359237) },
            { label: "st", name: "Stone", ...linear(6.35029318) },
            { label: "slug", name: "Slug", ...linear(14.593903) },
            { label: "short tn", name: "Short Ton", ...linear(907.18474) },
            { label: "long tn", name: "Long Ton", ...linear(1016.0469088) },
            { label: "t", name: "Metric Ton", ...linear(1000) },
        ],
    },
    {
        key: "volume",
        label: "Volume",
        icon: "flask-conical",
        type: "unit",
        units: [
            { label: "ml", name: "Milliliter", ...linear(0.001) },
            { label: "L", name: "Liter", ...linear(1) },
            { label: "gal", name: "Gallon", ...linear(3.785411784) },
            { label: "qt", name: "Quart", ...linear(0.946352946) },
            { label: "pt", name: "Pint", ...linear(0.473176473) },
            { label: "cup", name: "Cup", ...linear(0.2365882365) },
            { label: "fl oz", name: "Fluid Ounce", ...linear(0.029573529) },
        ],
    },
    {
        key: "speed",
        label: "Speed",
        icon: "gauge",
        type: "unit",
        units: [
            { label: "m/s", name: "Meter per Second", ...linear(1) },
            { label: "km/h", name: "Kilometer per Hour", ...linear(1 / 3.6) },
            { label: "mph", name: "Mile per Hour", ...linear(0.44704) },
            { label: "knots", name: "Knot", ...linear(0.514444) },
        ],
    },
    {
        key: "pressure",
        label: "Pressure",
        icon: "arrow-down-to-line",
        type: "unit",
        units: [
            { label: "Pa", name: "Pascal", ...linear(1) },
            { label: "kPa", name: "Kilopascal", ...linear(1000) },
            { label: "bar", name: "Bar", ...linear(100000) },
            { label: "atm", name: "Atmosphere", ...linear(101325) },
            { label: "PSI", name: "Pound per Sq Inch", ...linear(6894.757293168) },
            { label: "inHg", name: "Inch of Mercury", ...linear(3386.389) },
            { label: "Torr", name: "Torr", ...linear(133.3223684211) },
        ],
    },
    {
        key: "power",
        label: "Power",
        icon: "zap",
        type: "unit",
        units: [
            { label: "W", name: "Watt", ...linear(1) },
            { label: "kW", name: "Kilowatt", ...linear(1000) },
            { label: "hp", name: "Horsepower", ...linear(745.69987158) },
            { label: "BTU/min", name: "BTU per Minute", ...linear(17.584264) },
        ],
    },
    {
        key: "temperature",
        label: "Temp",
        icon: "thermometer",
        type: "unit",
        units: [
            {
                label: "\u00B0C",
                name: "Celsius",
                toBase: (v) => v,
                fromBase: (v) => v,
            },
            {
                label: "\u00B0F",
                name: "Fahrenheit",
                toBase: (v) => (v - 32) * (5 / 9),
                fromBase: (v) => v * (9 / 5) + 32,
            },
            {
                label: "K",
                name: "Kelvin",
                toBase: (v) => v - 273.15,
                fromBase: (v) => v + 273.15,
            },
        ],
    },
    {
        key: "angle",
        label: "Angle",
        icon: "triangle",
        type: "unit",
        units: [
            { label: "rad", name: "Radian", ...linear(1) },
            { label: "mrad", name: "Milliradian", ...linear(0.001) },
            { label: "\u00B5rad", name: "Microradian", ...linear(0.000001) },
            { label: "\u00B0", name: "Degree", ...linear(Math.PI / 180) },
            { label: "arcmin", name: "Arcminute", ...linear(Math.PI / 10800) },
            { label: "arcsec", name: "Arcsecond", ...linear(Math.PI / 648000) },
            { label: "mas", name: "Milliarcsecond", ...linear(Math.PI / 648000000) },
            { label: "\u00B5as", name: "Microarcsecond", ...linear(Math.PI / 648000000000) },
        ],
    },
    {
        key: "energy",
        label: "Energy",
        icon: "flame",
        type: "unit",
        units: [
            { label: "J", name: "Joule", ...linear(1) },
            { label: "kJ", name: "Kilojoule", ...linear(1000) },
            { label: "cal", name: "Calorie", ...linear(4.184) },
            { label: "kcal", name: "Kilocalorie", ...linear(4184) },
            { label: "BTU", name: "British Thermal Unit", ...linear(1055.06) },
            { label: "kWh", name: "Kilowatt-Hour", ...linear(3600000) },
            { label: "erg", name: "Erg", ...linear(0.0000001) },
            { label: "ft\u00B7lbf", name: "Foot-Pound", ...linear(1.3558179483) },
            { label: "N\u00B7m", name: "Newton-Meter", ...linear(1) },
        ],
    },
    {
        key: "force",
        label: "Force",
        icon: "move",
        type: "unit",
        units: [
            { label: "N", name: "Newton", ...linear(1) },
            { label: "kgf", name: "Kilogram-Force", ...linear(9.80665) },
            { label: "lbf", name: "Pound-Force", ...linear(4.4482216152605) },
            { label: "pdl", name: "Poundal", ...linear(0.138254954376) },
            { label: "dyn", name: "Dyne", ...linear(0.00001) },
        ],
    },
    {
        key: "fuel",
        label: "Fuel",
        icon: "fuel",
        type: "unit",
        units: [
            { label: "km/L", name: "Kilometer per Liter", ...linear(1) },
            { label: "mpg", name: "Mile per Gallon", ...linear(0.425143707) },
            {
                label: "L/100km",
                name: "Liter per 100km",
                toBase: (v) => 100 / v,
                fromBase: (v) => 100 / v,
            },
            {
                label: "gal/100mi",
                name: "Gallon per 100mi",
                toBase: (v) => 42.51437 / v,
                fromBase: (v) => 42.51437 / v,
            },
        ],
    },
    {
        key: "time",
        label: "Time",
        icon: "clock",
        type: "unit",
        units: [
            { label: "ms", name: "Millisecond", ...linear(0.001) },
            { label: "s", name: "Second", ...linear(1) },
            { label: "min", name: "Minute", ...linear(60) },
            { label: "hr", name: "Hour", ...linear(3600) },
            { label: "day", name: "Day", ...linear(86400) },
            { label: "week", name: "Week", ...linear(604800) },
            { label: "year", name: "Year", ...linear(31557600) },
        ],
    },
    {
        key: "data",
        label: "Data",
        icon: "database",
        type: "unit",
        units: [
            { label: "B", name: "Byte", ...linear(1) },
            { label: "KB", name: "Kilobyte", ...linear(1024) },
            { label: "MB", name: "Megabyte", ...linear(1048576) },
            { label: "GB", name: "Gigabyte", ...linear(1073741824) },
            { label: "TB", name: "Terabyte", ...linear(1099511627776) },
            { label: "PB", name: "Petabyte", ...linear(1125899906842624) },
        ],
    },
    {
        key: "age",
        label: "Age",
        icon: "cake",
        type: "calculator",
        fields: ["year", "month", "day"],
    },
    {
        key: "bmi",
        label: "BMI",
        icon: "heart-pulse",
        type: "calculator",
        fields: ["height", "weight"],
    },
    {
        key: "date",
        label: "Date",
        icon: "calendar",
        type: "calculator",
        fields: ["year1", "month1", "day1", "year2", "month2", "day2"],
    },
    {
        key: "discount",
        label: "Discount",
        icon: "tag",
        type: "calculator",
        fields: ["price", "percent"],
    },
    {
        key: "loan",
        label: "Loan",
        icon: "landmark",
        type: "calculator",
        fields: ["principal", "rate", "years"],
    },
]
