// Template files for `ric10 init <name>`.
// ic10Bindings is a verbatim copy of src/compiler/IC10.res (a test keeps them in sync).

let ic10Bindings = `// IC10.res - ReScript bindings for the ric10 compiler.
//
// These are type-checking stubs: running your program through the real
// ReScript compiler (with -open IC10) proves it is well-typed, while ric10
// recognises the same names and emits IC10 instructions for them.
// Math: use the standard library (Math.abs, Math.sqrt, Math.floor, Math.min,
// Math.max, Math.sin, ..., Float.toInt, Int.toFloat) - ric10 maps those too.

type device

type batchMode = Average | Sum | Minimum | Maximum

type reagentMode = Contents | Required | Recipe | TotalContents

// Values written to devices may be int, float or bool (true = 1).

// --- devices -------------------------------------------------------------

// Device pin: device("d0") .. device("d5"), device("db") (the IC housing)
let device = (_pin: string): device => Obj.magic(0)
let d0: device = Obj.magic(0)
let d1: device = Obj.magic(1)
let d2: device = Obj.magic(2)
let d3: device = Obj.magic(3)
let d4: device = Obj.magic(4)
let d5: device = Obj.magic(5)
let db: device = Obj.magic(-1)

// HASH("StructureVolumePump")
let hash = (_name: string): int => 0

// Every device of a prefab type on the network (lb/sb); l reads the Maximum,
// use lm for another batch mode
let batch = (_prefabHash: int): device => Obj.magic(0)
// Devices of a prefab type with a given name (lbn/sbn)
let named = (_prefabHash: int, _nameHash: int): device => Obj.magic(0)
// Batch read with an explicit mode: lm(tanks, "Pressure", Average)
let lm = (_device: device, _logicType: string, _mode: batchMode): float => 0.0

// l r? d? logicType
let l = (_device: device, _logicType: string): float => 0.0
// s d? logicType value
let s = (_device: device, _logicType: string, _value: 'a): unit => ()
// ls r? d? slot slotLogicType
let ls = (_device: device, _slot: int, _slotLogicType: string): float => 0.0
// ss d? slot slotLogicType value
let ss = (_device: device, _slot: int, _slotLogicType: string, _value: 'a): unit => ()
// lr r? d? reagentMode reagentHash
let lr = (_device: device, _mode: reagentMode, _reagent: int): float => 0.0
// sdse / sdns: is a device connected to the pin?
let isSet = (_device: device): bool => false
let isNotSet = (_device: device): bool => true

// --- batch operations on every device of a prefab type ---------------------

let lb = (_prefabHash: int, _logicType: string, _mode: batchMode): float => 0.0
let lbn = (_prefabHash: int, _nameHash: int, _logicType: string, _mode: batchMode): float => 0.0
let lbs = (_prefabHash: int, _slot: int, _slotLogicType: string, _mode: batchMode): float => 0.0
let lbns = (
  _prefabHash: int,
  _nameHash: int,
  _slot: int,
  _slotLogicType: string,
  _mode: batchMode,
): float => 0.0
let sb = (_prefabHash: int, _logicType: string, _value: 'a): unit => ()
let sbn = (_prefabHash: int, _nameHash: int, _logicType: string, _value: 'a): unit => ()
let sbs = (_prefabHash: int, _slot: int, _slotLogicType: string, _value: 'a): unit => ()

// --- execution ----------------------------------------------------------

// Pause until the next game tick
let yield = (): unit => ()
// Pause for a number of seconds
let sleep = (_seconds: float): unit => ()

// --- stack memory (512 slots) ---------------------------------------------

let push = (_value: 'a): unit => ()
let pop = (): float => 0.0
let peek = (): float => 0.0
let get = (_device: device, _address: int): float => 0.0
let put = (_device: device, _address: int, _value: 'a): unit => ()
// Stack memory of a device addressed by ReferenceId (getd / putd)
let getd = (_referenceId: float, _address: int): float => 0.0
let putd = (_referenceId: float, _address: int, _value: 'a): unit => ()

// --- misc -----------------------------------------------------------------

// Halt and catch fire: stops the chip
let hcf = (): unit => ()
// Approximate equality as the game computes it (sap): |a - b| <= eps * max(|a|, |b|)
let approx = (a: float, b: float, eps: float): bool => Math.abs(a -. b) <= eps *. Math.max(Math.abs(a), Math.abs(b))
// |a| <= eps (sapz)
let approxZero = (a: float, eps: float): bool => Math.abs(a) <= eps *. Math.abs(a)
// Branch-free conditional: select r? cond a b
let select = (cond: bool, a: 'a, b: 'a): 'a => cond ? a : b
// Linear interpolation, compiled to arithmetic (not clamped)
let lerp = (a: float, b: float, t: float): float => a +. (b -. a) *. t
let rand = (): float => 0.0

// --- BEGIN GENERATED (scripts/gen-bindings.mjs) ---
// Typed accessors for every logic type the game knows: Logic.temperature(d) is
// l(d, "Temperature"), Logic.setOn(d, v) is s(d, "On", v); a typo is a type error.
module Logic = {
  let power = (d: device): float => l(d, "Power")
  let setPower = (d: device, v: 'a): unit => s(d, "Power", v)
  let open_ = (d: device): float => l(d, "Open")
  let setOpen = (d: device, v: 'a): unit => s(d, "Open", v)
  let mode = (d: device): float => l(d, "Mode")
  let setMode = (d: device, v: 'a): unit => s(d, "Mode", v)
  let error = (d: device): float => l(d, "Error")
  let setError = (d: device, v: 'a): unit => s(d, "Error", v)
  let lock = (d: device): float => l(d, "Lock")
  let setLock = (d: device, v: 'a): unit => s(d, "Lock", v)
  let pressure = (d: device): float => l(d, "Pressure")
  let setPressure = (d: device, v: 'a): unit => s(d, "Pressure", v)
  let temperature = (d: device): float => l(d, "Temperature")
  let setTemperature = (d: device, v: 'a): unit => s(d, "Temperature", v)
  let pressureExternal = (d: device): float => l(d, "PressureExternal")
  let setPressureExternal = (d: device, v: 'a): unit => s(d, "PressureExternal", v)
  let pressureInternal = (d: device): float => l(d, "PressureInternal")
  let setPressureInternal = (d: device, v: 'a): unit => s(d, "PressureInternal", v)
  let activate = (d: device): float => l(d, "Activate")
  let setActivate = (d: device, v: 'a): unit => s(d, "Activate", v)
  let charge = (d: device): float => l(d, "Charge")
  let setCharge = (d: device, v: 'a): unit => s(d, "Charge", v)
  let setting = (d: device): float => l(d, "Setting")
  let setSetting = (d: device, v: 'a): unit => s(d, "Setting", v)
  let reagents = (d: device): float => l(d, "Reagents")
  let setReagents = (d: device, v: 'a): unit => s(d, "Reagents", v)
  let ratioOxygen = (d: device): float => l(d, "RatioOxygen")
  let setRatioOxygen = (d: device, v: 'a): unit => s(d, "RatioOxygen", v)
  let ratioCarbonDioxide = (d: device): float => l(d, "RatioCarbonDioxide")
  let setRatioCarbonDioxide = (d: device, v: 'a): unit => s(d, "RatioCarbonDioxide", v)
  let ratioNitrogen = (d: device): float => l(d, "RatioNitrogen")
  let setRatioNitrogen = (d: device, v: 'a): unit => s(d, "RatioNitrogen", v)
  let ratioPollutant = (d: device): float => l(d, "RatioPollutant")
  let setRatioPollutant = (d: device, v: 'a): unit => s(d, "RatioPollutant", v)
  let ratioVolatiles = (d: device): float => l(d, "RatioVolatiles")
  let setRatioVolatiles = (d: device, v: 'a): unit => s(d, "RatioVolatiles", v)
  let ratioWater = (d: device): float => l(d, "RatioWater")
  let setRatioWater = (d: device, v: 'a): unit => s(d, "RatioWater", v)
  let horizontal = (d: device): float => l(d, "Horizontal")
  let setHorizontal = (d: device, v: 'a): unit => s(d, "Horizontal", v)
  let vertical = (d: device): float => l(d, "Vertical")
  let setVertical = (d: device, v: 'a): unit => s(d, "Vertical", v)
  let solarAngle = (d: device): float => l(d, "SolarAngle")
  let setSolarAngle = (d: device, v: 'a): unit => s(d, "SolarAngle", v)
  let maximum = (d: device): float => l(d, "Maximum")
  let setMaximum = (d: device, v: 'a): unit => s(d, "Maximum", v)
  let ratio = (d: device): float => l(d, "Ratio")
  let setRatio = (d: device, v: 'a): unit => s(d, "Ratio", v)
  let powerPotential = (d: device): float => l(d, "PowerPotential")
  let setPowerPotential = (d: device, v: 'a): unit => s(d, "PowerPotential", v)
  let powerActual = (d: device): float => l(d, "PowerActual")
  let setPowerActual = (d: device, v: 'a): unit => s(d, "PowerActual", v)
  let quantity = (d: device): float => l(d, "Quantity")
  let setQuantity = (d: device, v: 'a): unit => s(d, "Quantity", v)
  let on = (d: device): float => l(d, "On")
  let setOn = (d: device, v: 'a): unit => s(d, "On", v)
  let importQuantity = (d: device): float => l(d, "ImportQuantity")
  let setImportQuantity = (d: device, v: 'a): unit => s(d, "ImportQuantity", v)
  let importSlotOccupant = (d: device): float => l(d, "ImportSlotOccupant")
  let setImportSlotOccupant = (d: device, v: 'a): unit => s(d, "ImportSlotOccupant", v)
  let exportQuantity = (d: device): float => l(d, "ExportQuantity")
  let setExportQuantity = (d: device, v: 'a): unit => s(d, "ExportQuantity", v)
  let exportSlotOccupant = (d: device): float => l(d, "ExportSlotOccupant")
  let setExportSlotOccupant = (d: device, v: 'a): unit => s(d, "ExportSlotOccupant", v)
  let requiredPower = (d: device): float => l(d, "RequiredPower")
  let setRequiredPower = (d: device, v: 'a): unit => s(d, "RequiredPower", v)
  let horizontalRatio = (d: device): float => l(d, "HorizontalRatio")
  let setHorizontalRatio = (d: device, v: 'a): unit => s(d, "HorizontalRatio", v)
  let verticalRatio = (d: device): float => l(d, "VerticalRatio")
  let setVerticalRatio = (d: device, v: 'a): unit => s(d, "VerticalRatio", v)
  let powerRequired = (d: device): float => l(d, "PowerRequired")
  let setPowerRequired = (d: device, v: 'a): unit => s(d, "PowerRequired", v)
  let idle = (d: device): float => l(d, "Idle")
  let setIdle = (d: device, v: 'a): unit => s(d, "Idle", v)
  let color = (d: device): float => l(d, "Color")
  let setColor = (d: device, v: 'a): unit => s(d, "Color", v)
  let elevatorSpeed = (d: device): float => l(d, "ElevatorSpeed")
  let setElevatorSpeed = (d: device, v: 'a): unit => s(d, "ElevatorSpeed", v)
  let elevatorLevel = (d: device): float => l(d, "ElevatorLevel")
  let setElevatorLevel = (d: device, v: 'a): unit => s(d, "ElevatorLevel", v)
  let recipeHash = (d: device): float => l(d, "RecipeHash")
  let setRecipeHash = (d: device, v: 'a): unit => s(d, "RecipeHash", v)
  let exportSlotHash = (d: device): float => l(d, "ExportSlotHash")
  let setExportSlotHash = (d: device, v: 'a): unit => s(d, "ExportSlotHash", v)
  let importSlotHash = (d: device): float => l(d, "ImportSlotHash")
  let setImportSlotHash = (d: device, v: 'a): unit => s(d, "ImportSlotHash", v)
  let plantHealth1 = (d: device): float => l(d, "PlantHealth1")
  let setPlantHealth1 = (d: device, v: 'a): unit => s(d, "PlantHealth1", v)
  let plantHealth2 = (d: device): float => l(d, "PlantHealth2")
  let setPlantHealth2 = (d: device, v: 'a): unit => s(d, "PlantHealth2", v)
  let plantHealth3 = (d: device): float => l(d, "PlantHealth3")
  let setPlantHealth3 = (d: device, v: 'a): unit => s(d, "PlantHealth3", v)
  let plantHealth4 = (d: device): float => l(d, "PlantHealth4")
  let setPlantHealth4 = (d: device, v: 'a): unit => s(d, "PlantHealth4", v)
  let plantGrowth1 = (d: device): float => l(d, "PlantGrowth1")
  let setPlantGrowth1 = (d: device, v: 'a): unit => s(d, "PlantGrowth1", v)
  let plantGrowth2 = (d: device): float => l(d, "PlantGrowth2")
  let setPlantGrowth2 = (d: device, v: 'a): unit => s(d, "PlantGrowth2", v)
  let plantGrowth3 = (d: device): float => l(d, "PlantGrowth3")
  let setPlantGrowth3 = (d: device, v: 'a): unit => s(d, "PlantGrowth3", v)
  let plantGrowth4 = (d: device): float => l(d, "PlantGrowth4")
  let setPlantGrowth4 = (d: device, v: 'a): unit => s(d, "PlantGrowth4", v)
  let plantEfficiency1 = (d: device): float => l(d, "PlantEfficiency1")
  let setPlantEfficiency1 = (d: device, v: 'a): unit => s(d, "PlantEfficiency1", v)
  let plantEfficiency2 = (d: device): float => l(d, "PlantEfficiency2")
  let setPlantEfficiency2 = (d: device, v: 'a): unit => s(d, "PlantEfficiency2", v)
  let plantEfficiency3 = (d: device): float => l(d, "PlantEfficiency3")
  let setPlantEfficiency3 = (d: device, v: 'a): unit => s(d, "PlantEfficiency3", v)
  let plantEfficiency4 = (d: device): float => l(d, "PlantEfficiency4")
  let setPlantEfficiency4 = (d: device, v: 'a): unit => s(d, "PlantEfficiency4", v)
  let plantHash1 = (d: device): float => l(d, "PlantHash1")
  let setPlantHash1 = (d: device, v: 'a): unit => s(d, "PlantHash1", v)
  let plantHash2 = (d: device): float => l(d, "PlantHash2")
  let setPlantHash2 = (d: device, v: 'a): unit => s(d, "PlantHash2", v)
  let plantHash3 = (d: device): float => l(d, "PlantHash3")
  let setPlantHash3 = (d: device, v: 'a): unit => s(d, "PlantHash3", v)
  let plantHash4 = (d: device): float => l(d, "PlantHash4")
  let setPlantHash4 = (d: device, v: 'a): unit => s(d, "PlantHash4", v)
  let requestHash = (d: device): float => l(d, "RequestHash")
  let setRequestHash = (d: device, v: 'a): unit => s(d, "RequestHash", v)
  let completionRatio = (d: device): float => l(d, "CompletionRatio")
  let setCompletionRatio = (d: device, v: 'a): unit => s(d, "CompletionRatio", v)
  let clearMemory = (d: device): float => l(d, "ClearMemory")
  let setClearMemory = (d: device, v: 'a): unit => s(d, "ClearMemory", v)
  let exportCount = (d: device): float => l(d, "ExportCount")
  let setExportCount = (d: device, v: 'a): unit => s(d, "ExportCount", v)
  let importCount = (d: device): float => l(d, "ImportCount")
  let setImportCount = (d: device, v: 'a): unit => s(d, "ImportCount", v)
  let powerGeneration = (d: device): float => l(d, "PowerGeneration")
  let setPowerGeneration = (d: device, v: 'a): unit => s(d, "PowerGeneration", v)
  let totalMoles = (d: device): float => l(d, "TotalMoles")
  let setTotalMoles = (d: device, v: 'a): unit => s(d, "TotalMoles", v)
  let volume = (d: device): float => l(d, "Volume")
  let setVolume = (d: device, v: 'a): unit => s(d, "Volume", v)
  let plant = (d: device): float => l(d, "Plant")
  let setPlant = (d: device, v: 'a): unit => s(d, "Plant", v)
  let harvest = (d: device): float => l(d, "Harvest")
  let setHarvest = (d: device, v: 'a): unit => s(d, "Harvest", v)
  let output = (d: device): float => l(d, "Output")
  let setOutput = (d: device, v: 'a): unit => s(d, "Output", v)
  let pressureSetting = (d: device): float => l(d, "PressureSetting")
  let setPressureSetting = (d: device, v: 'a): unit => s(d, "PressureSetting", v)
  let temperatureSetting = (d: device): float => l(d, "TemperatureSetting")
  let setTemperatureSetting = (d: device, v: 'a): unit => s(d, "TemperatureSetting", v)
  let temperatureExternal = (d: device): float => l(d, "TemperatureExternal")
  let setTemperatureExternal = (d: device, v: 'a): unit => s(d, "TemperatureExternal", v)
  let filtration = (d: device): float => l(d, "Filtration")
  let setFiltration = (d: device, v: 'a): unit => s(d, "Filtration", v)
  let airRelease = (d: device): float => l(d, "AirRelease")
  let setAirRelease = (d: device, v: 'a): unit => s(d, "AirRelease", v)
  let positionX = (d: device): float => l(d, "PositionX")
  let setPositionX = (d: device, v: 'a): unit => s(d, "PositionX", v)
  let positionY = (d: device): float => l(d, "PositionY")
  let setPositionY = (d: device, v: 'a): unit => s(d, "PositionY", v)
  let positionZ = (d: device): float => l(d, "PositionZ")
  let setPositionZ = (d: device, v: 'a): unit => s(d, "PositionZ", v)
  let velocityMagnitude = (d: device): float => l(d, "VelocityMagnitude")
  let setVelocityMagnitude = (d: device, v: 'a): unit => s(d, "VelocityMagnitude", v)
  let velocityRelativeX = (d: device): float => l(d, "VelocityRelativeX")
  let setVelocityRelativeX = (d: device, v: 'a): unit => s(d, "VelocityRelativeX", v)
  let velocityRelativeY = (d: device): float => l(d, "VelocityRelativeY")
  let setVelocityRelativeY = (d: device, v: 'a): unit => s(d, "VelocityRelativeY", v)
  let velocityRelativeZ = (d: device): float => l(d, "VelocityRelativeZ")
  let setVelocityRelativeZ = (d: device, v: 'a): unit => s(d, "VelocityRelativeZ", v)
  let ratioNitrousOxide = (d: device): float => l(d, "RatioNitrousOxide")
  let setRatioNitrousOxide = (d: device, v: 'a): unit => s(d, "RatioNitrousOxide", v)
  let prefabHash = (d: device): float => l(d, "PrefabHash")
  let setPrefabHash = (d: device, v: 'a): unit => s(d, "PrefabHash", v)
  let forceWrite = (d: device): float => l(d, "ForceWrite")
  let setForceWrite = (d: device, v: 'a): unit => s(d, "ForceWrite", v)
  let signalStrength = (d: device): float => l(d, "SignalStrength")
  let setSignalStrength = (d: device, v: 'a): unit => s(d, "SignalStrength", v)
  let signalID = (d: device): float => l(d, "SignalID")
  let setSignalID = (d: device, v: 'a): unit => s(d, "SignalID", v)
  let targetX = (d: device): float => l(d, "TargetX")
  let setTargetX = (d: device, v: 'a): unit => s(d, "TargetX", v)
  let targetY = (d: device): float => l(d, "TargetY")
  let setTargetY = (d: device, v: 'a): unit => s(d, "TargetY", v)
  let targetZ = (d: device): float => l(d, "TargetZ")
  let setTargetZ = (d: device, v: 'a): unit => s(d, "TargetZ", v)
  let settingInput = (d: device): float => l(d, "SettingInput")
  let setSettingInput = (d: device, v: 'a): unit => s(d, "SettingInput", v)
  let settingOutput = (d: device): float => l(d, "SettingOutput")
  let setSettingOutput = (d: device, v: 'a): unit => s(d, "SettingOutput", v)
  let currentResearchPodType = (d: device): float => l(d, "CurrentResearchPodType")
  let setCurrentResearchPodType = (d: device, v: 'a): unit => s(d, "CurrentResearchPodType", v)
  let manualResearchRequiredPod = (d: device): float => l(d, "ManualResearchRequiredPod")
  let setManualResearchRequiredPod = (d: device, v: 'a): unit => s(d, "ManualResearchRequiredPod", v)
  let mineablesInVicinity = (d: device): float => l(d, "MineablesInVicinity")
  let setMineablesInVicinity = (d: device, v: 'a): unit => s(d, "MineablesInVicinity", v)
  let mineablesInQueue = (d: device): float => l(d, "MineablesInQueue")
  let setMineablesInQueue = (d: device, v: 'a): unit => s(d, "MineablesInQueue", v)
  let nextWeatherEventTime = (d: device): float => l(d, "NextWeatherEventTime")
  let setNextWeatherEventTime = (d: device, v: 'a): unit => s(d, "NextWeatherEventTime", v)
  let combustion = (d: device): float => l(d, "Combustion")
  let setCombustion = (d: device, v: 'a): unit => s(d, "Combustion", v)
  let fuel = (d: device): float => l(d, "Fuel")
  let setFuel = (d: device, v: 'a): unit => s(d, "Fuel", v)
  let returnFuelCost = (d: device): float => l(d, "ReturnFuelCost")
  let setReturnFuelCost = (d: device, v: 'a): unit => s(d, "ReturnFuelCost", v)
  let collectableGoods = (d: device): float => l(d, "CollectableGoods")
  let setCollectableGoods = (d: device, v: 'a): unit => s(d, "CollectableGoods", v)
  let time = (d: device): float => l(d, "Time")
  let setTime = (d: device, v: 'a): unit => s(d, "Time", v)
  let bpm = (d: device): float => l(d, "Bpm")
  let setBpm = (d: device, v: 'a): unit => s(d, "Bpm", v)
  let environmentEfficiency = (d: device): float => l(d, "EnvironmentEfficiency")
  let setEnvironmentEfficiency = (d: device, v: 'a): unit => s(d, "EnvironmentEfficiency", v)
  let workingGasEfficiency = (d: device): float => l(d, "WorkingGasEfficiency")
  let setWorkingGasEfficiency = (d: device, v: 'a): unit => s(d, "WorkingGasEfficiency", v)
  let pressureInput = (d: device): float => l(d, "PressureInput")
  let setPressureInput = (d: device, v: 'a): unit => s(d, "PressureInput", v)
  let temperatureInput = (d: device): float => l(d, "TemperatureInput")
  let setTemperatureInput = (d: device, v: 'a): unit => s(d, "TemperatureInput", v)
  let ratioOxygenInput = (d: device): float => l(d, "RatioOxygenInput")
  let setRatioOxygenInput = (d: device, v: 'a): unit => s(d, "RatioOxygenInput", v)
  let ratioCarbonDioxideInput = (d: device): float => l(d, "RatioCarbonDioxideInput")
  let setRatioCarbonDioxideInput = (d: device, v: 'a): unit => s(d, "RatioCarbonDioxideInput", v)
  let ratioNitrogenInput = (d: device): float => l(d, "RatioNitrogenInput")
  let setRatioNitrogenInput = (d: device, v: 'a): unit => s(d, "RatioNitrogenInput", v)
  let ratioPollutantInput = (d: device): float => l(d, "RatioPollutantInput")
  let setRatioPollutantInput = (d: device, v: 'a): unit => s(d, "RatioPollutantInput", v)
  let ratioVolatilesInput = (d: device): float => l(d, "RatioVolatilesInput")
  let setRatioVolatilesInput = (d: device, v: 'a): unit => s(d, "RatioVolatilesInput", v)
  let ratioWaterInput = (d: device): float => l(d, "RatioWaterInput")
  let setRatioWaterInput = (d: device, v: 'a): unit => s(d, "RatioWaterInput", v)
  let ratioNitrousOxideInput = (d: device): float => l(d, "RatioNitrousOxideInput")
  let setRatioNitrousOxideInput = (d: device, v: 'a): unit => s(d, "RatioNitrousOxideInput", v)
  let totalMolesInput = (d: device): float => l(d, "TotalMolesInput")
  let setTotalMolesInput = (d: device, v: 'a): unit => s(d, "TotalMolesInput", v)
  let pressureInput2 = (d: device): float => l(d, "PressureInput2")
  let setPressureInput2 = (d: device, v: 'a): unit => s(d, "PressureInput2", v)
  let temperatureInput2 = (d: device): float => l(d, "TemperatureInput2")
  let setTemperatureInput2 = (d: device, v: 'a): unit => s(d, "TemperatureInput2", v)
  let ratioOxygenInput2 = (d: device): float => l(d, "RatioOxygenInput2")
  let setRatioOxygenInput2 = (d: device, v: 'a): unit => s(d, "RatioOxygenInput2", v)
  let ratioCarbonDioxideInput2 = (d: device): float => l(d, "RatioCarbonDioxideInput2")
  let setRatioCarbonDioxideInput2 = (d: device, v: 'a): unit => s(d, "RatioCarbonDioxideInput2", v)
  let ratioNitrogenInput2 = (d: device): float => l(d, "RatioNitrogenInput2")
  let setRatioNitrogenInput2 = (d: device, v: 'a): unit => s(d, "RatioNitrogenInput2", v)
  let ratioPollutantInput2 = (d: device): float => l(d, "RatioPollutantInput2")
  let setRatioPollutantInput2 = (d: device, v: 'a): unit => s(d, "RatioPollutantInput2", v)
  let ratioVolatilesInput2 = (d: device): float => l(d, "RatioVolatilesInput2")
  let setRatioVolatilesInput2 = (d: device, v: 'a): unit => s(d, "RatioVolatilesInput2", v)
  let ratioWaterInput2 = (d: device): float => l(d, "RatioWaterInput2")
  let setRatioWaterInput2 = (d: device, v: 'a): unit => s(d, "RatioWaterInput2", v)
  let ratioNitrousOxideInput2 = (d: device): float => l(d, "RatioNitrousOxideInput2")
  let setRatioNitrousOxideInput2 = (d: device, v: 'a): unit => s(d, "RatioNitrousOxideInput2", v)
  let totalMolesInput2 = (d: device): float => l(d, "TotalMolesInput2")
  let setTotalMolesInput2 = (d: device, v: 'a): unit => s(d, "TotalMolesInput2", v)
  let pressureOutput = (d: device): float => l(d, "PressureOutput")
  let setPressureOutput = (d: device, v: 'a): unit => s(d, "PressureOutput", v)
  let temperatureOutput = (d: device): float => l(d, "TemperatureOutput")
  let setTemperatureOutput = (d: device, v: 'a): unit => s(d, "TemperatureOutput", v)
  let ratioOxygenOutput = (d: device): float => l(d, "RatioOxygenOutput")
  let setRatioOxygenOutput = (d: device, v: 'a): unit => s(d, "RatioOxygenOutput", v)
  let ratioCarbonDioxideOutput = (d: device): float => l(d, "RatioCarbonDioxideOutput")
  let setRatioCarbonDioxideOutput = (d: device, v: 'a): unit => s(d, "RatioCarbonDioxideOutput", v)
  let ratioNitrogenOutput = (d: device): float => l(d, "RatioNitrogenOutput")
  let setRatioNitrogenOutput = (d: device, v: 'a): unit => s(d, "RatioNitrogenOutput", v)
  let ratioPollutantOutput = (d: device): float => l(d, "RatioPollutantOutput")
  let setRatioPollutantOutput = (d: device, v: 'a): unit => s(d, "RatioPollutantOutput", v)
  let ratioVolatilesOutput = (d: device): float => l(d, "RatioVolatilesOutput")
  let setRatioVolatilesOutput = (d: device, v: 'a): unit => s(d, "RatioVolatilesOutput", v)
  let ratioWaterOutput = (d: device): float => l(d, "RatioWaterOutput")
  let setRatioWaterOutput = (d: device, v: 'a): unit => s(d, "RatioWaterOutput", v)
  let ratioNitrousOxideOutput = (d: device): float => l(d, "RatioNitrousOxideOutput")
  let setRatioNitrousOxideOutput = (d: device, v: 'a): unit => s(d, "RatioNitrousOxideOutput", v)
  let totalMolesOutput = (d: device): float => l(d, "TotalMolesOutput")
  let setTotalMolesOutput = (d: device, v: 'a): unit => s(d, "TotalMolesOutput", v)
  let pressureOutput2 = (d: device): float => l(d, "PressureOutput2")
  let setPressureOutput2 = (d: device, v: 'a): unit => s(d, "PressureOutput2", v)
  let temperatureOutput2 = (d: device): float => l(d, "TemperatureOutput2")
  let setTemperatureOutput2 = (d: device, v: 'a): unit => s(d, "TemperatureOutput2", v)
  let ratioOxygenOutput2 = (d: device): float => l(d, "RatioOxygenOutput2")
  let setRatioOxygenOutput2 = (d: device, v: 'a): unit => s(d, "RatioOxygenOutput2", v)
  let ratioCarbonDioxideOutput2 = (d: device): float => l(d, "RatioCarbonDioxideOutput2")
  let setRatioCarbonDioxideOutput2 = (d: device, v: 'a): unit => s(d, "RatioCarbonDioxideOutput2", v)
  let ratioNitrogenOutput2 = (d: device): float => l(d, "RatioNitrogenOutput2")
  let setRatioNitrogenOutput2 = (d: device, v: 'a): unit => s(d, "RatioNitrogenOutput2", v)
  let ratioPollutantOutput2 = (d: device): float => l(d, "RatioPollutantOutput2")
  let setRatioPollutantOutput2 = (d: device, v: 'a): unit => s(d, "RatioPollutantOutput2", v)
  let ratioVolatilesOutput2 = (d: device): float => l(d, "RatioVolatilesOutput2")
  let setRatioVolatilesOutput2 = (d: device, v: 'a): unit => s(d, "RatioVolatilesOutput2", v)
  let ratioWaterOutput2 = (d: device): float => l(d, "RatioWaterOutput2")
  let setRatioWaterOutput2 = (d: device, v: 'a): unit => s(d, "RatioWaterOutput2", v)
  let ratioNitrousOxideOutput2 = (d: device): float => l(d, "RatioNitrousOxideOutput2")
  let setRatioNitrousOxideOutput2 = (d: device, v: 'a): unit => s(d, "RatioNitrousOxideOutput2", v)
  let totalMolesOutput2 = (d: device): float => l(d, "TotalMolesOutput2")
  let setTotalMolesOutput2 = (d: device, v: 'a): unit => s(d, "TotalMolesOutput2", v)
  let combustionInput = (d: device): float => l(d, "CombustionInput")
  let setCombustionInput = (d: device, v: 'a): unit => s(d, "CombustionInput", v)
  let combustionInput2 = (d: device): float => l(d, "CombustionInput2")
  let setCombustionInput2 = (d: device, v: 'a): unit => s(d, "CombustionInput2", v)
  let combustionOutput = (d: device): float => l(d, "CombustionOutput")
  let setCombustionOutput = (d: device, v: 'a): unit => s(d, "CombustionOutput", v)
  let combustionOutput2 = (d: device): float => l(d, "CombustionOutput2")
  let setCombustionOutput2 = (d: device, v: 'a): unit => s(d, "CombustionOutput2", v)
  let operationalTemperatureEfficiency = (d: device): float => l(d, "OperationalTemperatureEfficiency")
  let setOperationalTemperatureEfficiency = (d: device, v: 'a): unit => s(d, "OperationalTemperatureEfficiency", v)
  let temperatureDifferentialEfficiency = (d: device): float => l(d, "TemperatureDifferentialEfficiency")
  let setTemperatureDifferentialEfficiency = (d: device, v: 'a): unit => s(d, "TemperatureDifferentialEfficiency", v)
  let pressureEfficiency = (d: device): float => l(d, "PressureEfficiency")
  let setPressureEfficiency = (d: device, v: 'a): unit => s(d, "PressureEfficiency", v)
  let combustionLimiter = (d: device): float => l(d, "CombustionLimiter")
  let setCombustionLimiter = (d: device, v: 'a): unit => s(d, "CombustionLimiter", v)
  let throttle = (d: device): float => l(d, "Throttle")
  let setThrottle = (d: device, v: 'a): unit => s(d, "Throttle", v)
  let rpm = (d: device): float => l(d, "Rpm")
  let setRpm = (d: device, v: 'a): unit => s(d, "Rpm", v)
  let stress = (d: device): float => l(d, "Stress")
  let setStress = (d: device, v: 'a): unit => s(d, "Stress", v)
  let interrogationProgress = (d: device): float => l(d, "InterrogationProgress")
  let setInterrogationProgress = (d: device, v: 'a): unit => s(d, "InterrogationProgress", v)
  let targetPadIndex = (d: device): float => l(d, "TargetPadIndex")
  let setTargetPadIndex = (d: device, v: 'a): unit => s(d, "TargetPadIndex", v)
  let sizeX = (d: device): float => l(d, "SizeX")
  let setSizeX = (d: device, v: 'a): unit => s(d, "SizeX", v)
  let sizeY = (d: device): float => l(d, "SizeY")
  let setSizeY = (d: device, v: 'a): unit => s(d, "SizeY", v)
  let sizeZ = (d: device): float => l(d, "SizeZ")
  let setSizeZ = (d: device, v: 'a): unit => s(d, "SizeZ", v)
  let minimumWattsToContact = (d: device): float => l(d, "MinimumWattsToContact")
  let setMinimumWattsToContact = (d: device, v: 'a): unit => s(d, "MinimumWattsToContact", v)
  let wattsReachingContact = (d: device): float => l(d, "WattsReachingContact")
  let setWattsReachingContact = (d: device, v: 'a): unit => s(d, "WattsReachingContact", v)
}

// Slot accessors: Slot.occupied(d, 0) is ls(d, 0, "Occupied").
module Slot = {
  let occupied = (d: device, slot: int): float => ls(d, slot, "Occupied")
  let setOccupied = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Occupied", v)
  let occupantHash = (d: device, slot: int): float => ls(d, slot, "OccupantHash")
  let setOccupantHash = (d: device, slot: int, v: 'a): unit => ss(d, slot, "OccupantHash", v)
  let quantity = (d: device, slot: int): float => ls(d, slot, "Quantity")
  let setQuantity = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Quantity", v)
  let damage = (d: device, slot: int): float => ls(d, slot, "Damage")
  let setDamage = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Damage", v)
  let efficiency = (d: device, slot: int): float => ls(d, slot, "Efficiency")
  let setEfficiency = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Efficiency", v)
  let health = (d: device, slot: int): float => ls(d, slot, "Health")
  let setHealth = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Health", v)
  let growth = (d: device, slot: int): float => ls(d, slot, "Growth")
  let setGrowth = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Growth", v)
  let pressure = (d: device, slot: int): float => ls(d, slot, "Pressure")
  let setPressure = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Pressure", v)
  let temperature = (d: device, slot: int): float => ls(d, slot, "Temperature")
  let setTemperature = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Temperature", v)
  let charge = (d: device, slot: int): float => ls(d, slot, "Charge")
  let setCharge = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Charge", v)
  let chargeRatio = (d: device, slot: int): float => ls(d, slot, "ChargeRatio")
  let setChargeRatio = (d: device, slot: int, v: 'a): unit => ss(d, slot, "ChargeRatio", v)
  let class = (d: device, slot: int): float => ls(d, slot, "Class")
  let setClass = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Class", v)
  let pressureWaste = (d: device, slot: int): float => ls(d, slot, "PressureWaste")
  let setPressureWaste = (d: device, slot: int, v: 'a): unit => ss(d, slot, "PressureWaste", v)
  let pressureAir = (d: device, slot: int): float => ls(d, slot, "PressureAir")
  let setPressureAir = (d: device, slot: int, v: 'a): unit => ss(d, slot, "PressureAir", v)
  let maxQuantity = (d: device, slot: int): float => ls(d, slot, "MaxQuantity")
  let setMaxQuantity = (d: device, slot: int, v: 'a): unit => ss(d, slot, "MaxQuantity", v)
  let mature = (d: device, slot: int): float => ls(d, slot, "Mature")
  let setMature = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Mature", v)
  let prefabHash = (d: device, slot: int): float => ls(d, slot, "PrefabHash")
  let setPrefabHash = (d: device, slot: int, v: 'a): unit => ss(d, slot, "PrefabHash", v)
  let seeding = (d: device, slot: int): float => ls(d, slot, "Seeding")
  let setSeeding = (d: device, slot: int, v: 'a): unit => ss(d, slot, "Seeding", v)
}

// Prefab hashes of every device and item in the game: batch(Prefab.structureTankSmall).
// Compiled to HASH("StructureTankSmall"), or to the number when the prefab name is unknown.
module Prefab = {
  let accessCardBlack: int = -1330388999 // Access Card (Black)
  let accessCardBlue: int = -1411327657 // Access Card (Blue)
  let accessCardBrown: int = 1412428165 // Access Card (Brown)
  let accessCardGray: int = -1339479035 // Access Card (Gray)
  let accessCardGreen: int = -374567952 // Access Card (Green)
  let accessCardKhaki: int = 337035771 // Access Card (Khaki)
  let accessCardOrange: int = -332896929 // Access Card (Orange)
  let accessCardPink: int = 431317557 // Access Card (Pink)
  let accessCardPurple: int = 459843265 // Access Card (Purple)
  let accessCardRed: int = -1713748313 // Access Card (Red)
  let accessCardWhite: int = 2079959157 // Access Card (White)
  let accessCardYellow: int = 568932536 // Access Card (Yellow)
  let applianceChemistryStation: int = 1365789392 // Chemistry Station
  let applianceDeskLampLeft: int = -1683849799 // Appliance Desk Lamp Left
  let applianceDeskLampRight: int = 1174360780 // Appliance Desk Lamp Right
  let applianceMicrowave: int = -1136173965 // Microwave
  let appliancePackagingMachine: int = -749191906 // Basic Packaging Machine
  let appliancePaintMixer: int = -1339716113 // Paint Mixer
  let appliancePlantGeneticAnalyzer: int = -1303038067 // Plant Genetic Analyzer
  let appliancePlantGeneticSplicer: int = -1094868323 // Plant Genetic Splicer
  let appliancePlantGeneticStabilizer: int = 871432335 // Plant Genetic Stabilizer
  let applianceReagentProcessor: int = 1260918085 // Reagent Processor
  let applianceSeedTray: int = 142831994 // Appliance Seed Tray
  let autolathePrinterMod: int = 221058307 // Autolathe Printer Mod
  let automatedRocketAutomationModule: int = 1556756312 // Automated Rocket Automation Module
  let automatedRocketCouplingModuleDown: int = -379394005 // Automated Rocket Coupling Module (Down)
  let automatedRocketCouplingModuleUp: int = 761078460 // Automated Rocket Coupling Module (Up)
  let automatedRocketGasMiningModule: int = -1969723301 // Automated Rocket Gas Mining Module
  let automatedRocketIceMiningModule: int = 74521920 // Automated Rocket Ice Mining Module
  let automatedRocketOreMiningModule: int = -2027419821 // Automated Rocket Ore Mining Module
  let automatedRocketSalvageModule: int = -1446002463 // Automated Rocket Salvage Module
  let automatedRocketSiloModule: int = 906210602 // Automated Rocket Silo Module
  let battery_Wireless_cell: int = -462415758 // Battery Wireless Cell
  let battery_Wireless_cell_Big: int = -41519077 // Battery Wireless Cell (Big)
  let cartridgeAccessController: int = -1634532552 // Cartridge (Access Controller)
  let cartridgeAtmosAnalyser: int = -1550278665 // Atmos Analyzer
  let cartridgeConfiguration: int = -932136011 // Configuration
  let cartridgeElectronicReader: int = -1462180176 // eReader
  let cartridgeGPS: int = -1957063345 // GPS
  let cartridgeGuide: int = 872720793 // Guide
  let cartridgeMedicalAnalyser: int = -1116110181 // Medical Analyzer
  let cartridgeNetworkAnalyser: int = 1606989119 // Network Analyzer
  let cartridgeOreScanner: int = -1768732546 // Ore Scanner
  let cartridgeOreScannerColor: int = 1738236580 // Ore Scanner (Color)
  let cartridgePlantAnalyser: int = 1101328282 // Cartridge Plant Analyser
  let cartridgeTracker: int = 81488783 // Tracker
  let circuitboardAdvAirlockControl: int = 1633663176 // Advanced Airlock
  let circuitboardAirControl: int = 1618019559 // Air Control
  let circuitboardAirlockControl: int = 912176135 // Airlock
  let circuitboardCameraDisplay: int = -412104504 // Camera Display
  let circuitboardDoorControl: int = 855694771 // Door Control
  let circuitboardGasDisplay: int = -82343730 // Gas Display
  let circuitboardGraphDisplay: int = 1344368806 // Graph Display
  let circuitboardHashDisplay: int = 1633074601 // Hash Display
  let circuitboardModeControl: int = -1134148135 // Mode Control
  let circuitboardPowerControl: int = -1923778429 // Power Control
  let circuitboardShipDisplay: int = -2044446819 // Ship Display
  let circuitboardSolarControl: int = 2020180320 // Solar Control
  let compositeRollCover: int = 1228794916 // Composite Roll Cover
  let crateMkII: int = 8709219 // Crate Mk II
  let creativeRTG: int = -44928532 // Creative RTG
  let decayedFood: int = 1531087544 // Decayed Food
  let deviceLfoVolume: int = -1844430312 // Low frequency oscillator
  let deviceStepUnit: int = 1762696475 // Device Step Unit
  let dynamicAirConditioner: int = 519913639 // Portable Air Conditioner
  let dynamicCrate: int = 1941079206 // Dynamic Crate
  let dynamicGasCanisterAir: int = -1713611165 // Portable Gas Tank (Air)
  let dynamicGasCanisterCarbonDioxide: int = -322413931 // Portable Gas Tank (CO2)
  let dynamicGasCanisterEmpty: int = -1741267161 // Portable Gas Tank
  let dynamicGasCanisterFuel: int = -817051527 // Portable Gas Tank (Fuel)
  let dynamicGasCanisterNitrogen: int = 121951301 // Portable Gas Tank (Nitrogen)
  let dynamicGasCanisterNitrousOxide: int = 30727200 // Portable Gas Tank (Nitrous Oxide)
  let dynamicGasCanisterOxygen: int = 1360925836 // Portable Gas Tank (Oxygen)
  let dynamicGasCanisterPollutants: int = 396065382 // Portable Gas Tank (Pollutants)
  let dynamicGasCanisterRocketFuel: int = -8883951 // Dynamic Gas Canister Rocket Fuel
  let dynamicGasCanisterVolatiles: int = 108086870 // Portable Gas Tank (Volatiles)
  let dynamicGasCanisterWater: int = 197293625 // Portable Liquid Tank (Water)
  let dynamicGasTankAdvanced: int = -386375420 // Gas Tank Mk II
  let dynamicGasTankAdvancedOxygen: int = -1264455519 // Portable Gas Tank Mk II (Oxygen)
  let dynamicGenerator: int = -82087220 // Portable Generator
  let dynamicGPR: int = -2085885850 // Ground Penetrating Radar (GPR)
  let dynamicHydroponics: int = 587726607 // Portable Hydroponics
  let dynamicLight: int = -21970188 // Portable Light
  let dynamicLiquidCanisterEmpty: int = -1939209112 // Portable Liquid Tank
  let dynamicMKIILiquidCanisterEmpty: int = 2130739600 // Portable Liquid Tank Mk II
  let dynamicMKIILiquidCanisterWater: int = -319510386 // Portable Liquid Tank Mk II (Water)
  let dynamicScrubber: int = 755048589 // Portable Air Scrubber
  let dynamicSkeleton: int = 106953348 // Skeleton
  let electronicPrinterMod: int = -311170652 // Electronic Printer Mod
  let elevatorCarrage: int = -110788403 // Elevator
  let entityChick: int = 1730165908 // Entity Chick
  let entityChickenBrown: int = 334097180 // Entity Chicken Brown
  let entityChickenWhite: int = 1010807532 // Entity Chicken White
  let entityRoosterBlack: int = 966959649 // Entity Rooster Black
  let entityRoosterBrown: int = -583103395 // Entity Rooster Brown
  let fertilizer: int = 1517856652 // Fertilizer
  let fireArmSMG: int = -86315541 // Fire Arm SMG
  let flag_ODA_10m: int = 1845441951 // Flag (ODA 10m)
  let flag_ODA_4m: int = 1159126354 // Flag (ODA 4m)
  let flag_ODA_6m: int = 1998634960 // Flag (ODA 6m)
  let flag_ODA_8m: int = -375156130 // Flag (ODA 8m)
  let h2Combustor: int = 1840108251 // H2 Combustor
  let handgun: int = 247238062 // Handgun
  let handgunMagazine: int = 1254383185 // Handgun Magazine
  let humanSkull: int = -857713709 // Human Skull
  let imGuiCircuitboardAirlockControl: int = -73796547 // Airlock (Experimental)
  let insulatedLiquidPipeStraight: int = -916909854 // Insulated Liquid Pipe Straight
  let itemActiveVent: int = -842048328 // Kit (Active Vent)
  let itemAdvancedTablet: int = 1722785341 // Advanced Tablet
  let itemAlienMushroom: int = 176446172 // Alien Mushroom
  let itemAmmoBox: int = -9559091 // Ammo Box
  let itemAngleGrinder: int = 201215010 // Angle Grinder
  let itemArcWelder: int = 1385062886 // Arc Welder
  let itemAreaPowerControl: int = 1757673317 // Kit (Power Controller)
  let itemAstroloyIngot: int = 412924554 // Ingot (Astroloy)
  let itemAstroloySheets: int = -1662476145 // Astroloy Sheets
  let itemAuthoringTool: int = 789015045 // Authoring Tool
  let itemAuthoringToolRocketNetwork: int = -1731627004 // <N:EN:ItemAuthoringToolRocketNetwork>
  let itemBasketBall: int = -1262580790 // Basket Ball
  let itemBatteryCell: int = 700133157 // Battery Cell (Small)
  let itemBatteryCellLarge: int = -459827268 // Battery Cell (Large)
  let itemBatteryCellNuclear: int = 544617306 // Battery Cell (Nuclear)
  let itemBatteryCharger: int = -1866880307 // Kit (Battery Charger)
  let itemBatteryChargerSmall: int = 1008295833 // Battery Charger Small
  let itemBeacon: int = -869869491 // Tracking Beacon
  let itemBiomass: int = -831480639 // Biomass
  let itemBreadLoaf: int = 893514943 // Bread Loaf
  let itemCableAnalyser: int = -1792787349 // Kit (Cable Analyzer)
  let itemCableCoil: int = -466050668 // Cable Coil
  let itemCableCoilHeavy: int = 2060134443 // Cable Coil (Heavy)
  let itemCableFuse: int = 195442047 // Kit (Cable Fuses)
  let itemCannedCondensedMilk: int = -2104175091 // Canned Condensed Milk
  let itemCannedEdamame: int = -999714082 // Canned Edamame
  let itemCannedPowderedEggs: int = 1161510063 // Canned Powdered Eggs
  let itemCannedRicePudding: int = -1185552595 // Canned Rice Pudding
  let itemCerealBar: int = 791746840 // Cereal Bar
  let itemCharcoal: int = 252561409 // Charcoal
  let itemChemLightBlue: int = -772542081 // Chem Light (Blue)
  let itemChemLightGreen: int = -597479390 // Chem Light (Green)
  let itemChemLightRed: int = -525810132 // Chem Light (Red)
  let itemChemLightWhite: int = 1312166823 // Chem Light (White)
  let itemChemLightYellow: int = 1224819963 // Chem Light (Yellow)
  let itemCoalOre: int = 1724793494 // Ore (Coal)
  let itemCobaltOre: int = -983091249 // Ore (Cobalt)
  let itemCoffeeMug: int = 1800622698 // Coffee Mug
  let itemConstantanIngot: int = 1058547521 // Ingot (Constantan)
  let itemCookedCondensedMilk: int = 1715917521 // Condensed Milk
  let itemCookedCorn: int = 1344773148 // Cooked Corn
  let itemCookedPowderedEggs: int = -1712264413 // Powdered Eggs
  let itemCookedPumpkin: int = 1849281546 // Cooked Pumpkin
  let itemCookedRice: int = 2013539020 // Cooked Rice
  let itemCookedSoybean: int = 1353449022 // Cooked Soybean
  let itemCookedTomato: int = -709086714 // Cooked Tomato
  let itemCopperIngot: int = -404336834 // Ingot (Copper)
  let itemCopperOre: int = -707307845 // Ore (Copper)
  let itemCorn: int = 258339687 // Corn
  let itemCornSoup: int = 545034114 // Corn Soup
  let itemCreditCard: int = -1756772618 // Credit Card
  let itemCropHay: int = 215486157 // Hay
  let itemCrowbar: int = 856108234 // Crowbar
  let itemDataDisk: int = 1005843700 // Data Disk
  let itemDirtCanister: int = 902565329 // Dirt Canister
  let itemDirtyOre: int = -1234745580 // Dirty Ore
  let itemDisposableBatteryCharger: int = -2124435700 // Disposable Battery Charger
  let itemDrill: int = 2009673399 // Hand Drill
  let itemDuctTape: int = -1943134693 // Duct Tape
  let itemDynamicAirCon: int = 1072914031 // Kit (Portable Air Conditioner)
  let itemDynamicScrubber: int = -971920158 // Kit (Portable Scrubber)
  let itemEgg: int = -873909936 // Egg
  let itemEggCarton: int = -524289310 // Egg Carton
  let itemElectronicParts: int = 731250882 // Electronic Parts
  let itemElectrumIngot: int = 502280180 // Ingot (Electrum)
  let itemEmergencyAngleGrinder: int = -351438780 // Emergency Angle Grinder
  let itemEmergencyArcWelder: int = -1056029600 // Emergency Arc Welder
  let itemEmergencyCrowbar: int = 976699731 // Emergency Crowbar
  let itemEmergencyDrill: int = -2052458905 // Emergency Drill
  let itemEmergencyEvaSuit: int = 1791306431 // Emergency Eva Suit
  let itemEmergencyPickaxe: int = -1061510408 // Emergency Pickaxe
  let itemEmergencyScrewdriver: int = 266099983 // Emergency Screwdriver
  let itemEmergencySpaceHelmet: int = 205916793 // Emergency Space Helmet
  let itemEmergencyToolBelt: int = 1661941301 // Emergency Tool Belt
  let itemEmergencyWireCutters: int = 2102803952 // Emergency Wire Cutters
  let itemEmergencyWrench: int = 162553030 // Emergency Wrench
  let itemEmptyCan: int = 1013818348 // Empty Can
  let itemEvaSuit: int = 1677018918 // Eva Suit
  let itemExplosive: int = 235361649 // Remote Explosive
  let itemFern: int = 892110467 // Fern
  let itemFertilizedEgg: int = -383972371 // Fertilized Egg
  let itemFilterFern: int = 266654416 // Darga Fern
  let itemFireExtinguisher: int = 1578288856 // Fire Extinguisher
  let itemFlagSmall: int = 2011191088 // Kit (Small Flag)
  let itemFlashingLight: int = -2107840748 // Kit (Flashing Light)
  let itemFlour: int = -665995854 // Flour
  let itemFlowerBlue: int = -1573623434 // Flower (Blue)
  let itemFlowerGreen: int = -1513337058 // Flower (Green)
  let itemFlowerOrange: int = -1411986716 // Flower (Orange)
  let itemFlowerRed: int = -81376085 // Flower (Red)
  let itemFlowerYellow: int = 1712822019 // Flower (Yellow)
  let itemFrenchFries: int = -57608687 // Canned French Fries
  let itemFries: int = 1371786091 // French Fries
  let itemGasCanisterCarbonDioxide: int = -767685874 // Canister (CO2)
  let itemGasCanisterEmpty: int = 42280099 // Canister
  let itemGasCanisterFuel: int = -1014695176 // Canister (Fuel)
  let itemGasCanisterNitrogen: int = 2145068424 // Canister (Nitrogen)
  let itemGasCanisterNitrousOxide: int = -1712153401 // Gas Canister (Sleeping)
  let itemGasCanisterOxygen: int = -1152261938 // Canister (Oxygen)
  let itemGasCanisterPollutants: int = -1552586384 // Canister (Pollutants)
  let itemGasCanisterSmart: int = -668314371 // Gas Canister (Smart)
  let itemGasCanisterVolatiles: int = -472094806 // Canister (Volatiles)
  let itemGasCanisterWater: int = -1854861891 // Liquid Canister (Water)
  let itemGasFilterCarbonDioxide: int = 1635000764 // Filter (Carbon Dioxide)
  let itemGasFilterCarbonDioxideInfinite: int = -185568964 // Catalytic Filter (Carbon Dioxide)
  let itemGasFilterCarbonDioxideL: int = 1876847024 // Heavy Filter (Carbon Dioxide)
  let itemGasFilterCarbonDioxideM: int = 416897318 // Medium Filter (Carbon Dioxide)
  let itemGasFilterNitrogen: int = 632853248 // Filter (Nitrogen)
  let itemGasFilterNitrogenInfinite: int = 152751131 // Catalytic Filter (Nitrogen)
  let itemGasFilterNitrogenL: int = -1387439451 // Heavy Filter (Nitrogen)
  let itemGasFilterNitrogenM: int = -632657357 // Medium Filter (Nitrogen)
  let itemGasFilterNitrousOxide: int = -1247674305 // Filter (Nitrous Oxide)
  let itemGasFilterNitrousOxideInfinite: int = -123934842 // Catalytic Filter (Nitrous Oxide)
  let itemGasFilterNitrousOxideL: int = 465267979 // Heavy Filter (Nitrous Oxide)
  let itemGasFilterNitrousOxideM: int = 1824284061 // Medium Filter (Nitrous Oxide)
  let itemGasFilterOxygen: int = -721824748 // Filter (Oxygen)
  let itemGasFilterOxygenInfinite: int = -1055451111 // Catalytic Filter (Oxygen)
  let itemGasFilterOxygenL: int = -1217998945 // Heavy Filter (Oxygen)
  let itemGasFilterOxygenM: int = -1067319543 // Medium Filter (Oxygen)
  let itemGasFilterPollutants: int = 1915566057 // Filter (Pollutant)
  let itemGasFilterPollutantsInfinite: int = -503738105 // Catalytic Filter (Pollutants)
  let itemGasFilterPollutantsL: int = 1959564765 // Heavy Filter (Pollutants)
  let itemGasFilterPollutantsM: int = 63677771 // Medium Filter (Pollutants)
  let itemGasFilterVolatiles: int = 15011598 // Filter (Volatiles)
  let itemGasFilterVolatilesInfinite: int = -1916176068 // Catalytic Filter (Volatiles)
  let itemGasFilterVolatilesL: int = 1255156286 // Heavy Filter (Volatiles)
  let itemGasFilterVolatilesM: int = 1037507240 // Medium Filter (Volatiles)
  let itemGasFilterWater: int = -1993197973 // Filter (Water)
  let itemGasFilterWaterInfinite: int = -1678456554 // Catalytic Filter (Water)
  let itemGasFilterWaterL: int = 2004969680 // Heavy Filter (Water)
  let itemGasFilterWaterM: int = 8804422 // Medium Filter (Water)
  let itemGasSensor: int = 1717593480 // Kit (Gas Sensor)
  let itemGasTankStorage: int = -2113012215 // Kit (Canister Storage)
  let itemGlasses: int = -1068925231 // Glasses
  let itemGlassSheets: int = 1588896491 // Glass Sheets
  let itemGoldIngot: int = 226410516 // Ingot (Gold)
  let itemGoldOre: int = -1348105509 // Ore (Gold)
  let itemGrenade: int = 1544275894 // Hand Grenade
  let itemHardBackpack: int = 374891127 // Hardsuit Backpack
  let itemHardJetpack: int = -412551656 // Hardsuit Jetpack
  let itemHardMiningBackPack: int = 900366130 // Hard Mining Backpack
  let itemHardSuit: int = -1758310454 // Hardsuit
  let itemHardsuitHelmet: int = -84573099 // Hardsuit Helmet
  let itemHastelloyIngot: int = 1579842814 // Ingot (Hastelloy)
  let itemHat: int = 299189339 // Hat
  let itemHEMDroidRepairKit: int = 470636008 // HEMDroid Repair Kit
  let itemHighVolumeGasCanisterEmpty: int = 998653377 // High Volume Gas Canister
  let itemHydroponicTray: int = -1193543727 // Kit (Hydroponic Tray)
  let itemIce: int = 1217489948 // Ice (Water)
  let itemIgniter: int = 890106742 // Kit (Igniter)
  let itemInconelIngot: int = -787796599 // Ingot (Inconel)
  let itemInsulatedTankConnector: int = -299044195 // Insulated (Tank Connector)
  let itemInsulation: int = 897176943 // Insulation
  let itemIntegratedCircuit10: int = -744098481 // Integrated Circuit (IC10)
  let itemInvarIngot: int = -297990285 // Ingot (Invar)
  let itemIronFrames: int = 1225836666 // Iron Frames
  let itemIronIngot: int = -1301215609 // Ingot (Iron)
  let itemIronOre: int = 1758427767 // Ore (Iron)
  let itemIronSheets: int = -487378546 // Iron Sheets
  let itemJetpackBasic: int = 1969189000 // Jetpack Basic
  let itemKitAdvancedComposter: int = -1431998347 // Kit (Advanced Composter)
  let itemKitAdvancedFurnace: int = -616758353 // Kit (Advanced Furnace)
  let itemKitAdvancedPackagingMachine: int = -598545233 // Kit (Advanced Packaging Machine)
  let itemKitAIMeE: int = 496830914 // Kit (AIMeE)
  let itemKitAirlock: int = 964043875 // Kit (Airlock)
  let itemKitAirlockGate: int = 682546947 // Kit (Hangar Door)
  let itemKitArcFurnace: int = -98995857 // Kit (Arc Furnace)
  let itemKitAtmospherics: int = 1222286371 // Kit (Atmospherics)
  let itemKitAutolathe: int = -1753893214 // Kit (Autolathe)
  let itemKitAutomatedOven: int = -1931958659 // Kit (Automated Oven)
  let itemKitAutoMinerSmall: int = 1668815415 // Kit (Autominer Small)
  let itemKitBasket: int = 148305004 // Kit (Basket)
  let itemKitBattery: int = 1406656973 // Kit (Battery)
  let itemKitBatteryLarge: int = -21225041 // Kit (Battery Large)
  let itemKitBeacon: int = 249073136 // Kit (Beacon)
  let itemKitBeds: int = -1241256797 // Kit (Beds)
  let itemKitBlastDoor: int = -1755116240 // Kit (Blast Door)
  let itemKitCentrifuge: int = 578182956 // Kit (Centrifuge)
  let itemKitChairs: int = -1394008073 // Kit (Chairs)
  let itemKitChute: int = 1025254665 // Kit (Basic Chutes)
  let itemKitCompositeCladding: int = -1470820996 // Kit (Cladding)
  let itemKitCompositeFloorGrating: int = 1182412869 // Kit (Floor Grating)
  let itemKitComputer: int = 1990225489 // Kit (Computer)
  let itemKitConsole: int = -1241851179 // Kit (Consoles)
  let itemKitCrate: int = 429365598 // Kit (Crate)
  let itemKitCrateMkII: int = -1585956426 // Kit (Crate Mk II)
  let itemKitCrateMount: int = -551612946 // Kit (Container Mount)
  let itemKitCryoTube: int = -545234195 // Kit (Cryo Tube)
  let itemKitDeepMiner: int = -1935075707 // Kit (Deep Miner)
  let itemKitDockingPort: int = 77421200 // Kit (Docking Port)
  let itemKitDoor: int = 168615924 // Kit (Door)
  let itemKitDynamicCanister: int = -1061945368 // Kit (Portable Gas Tank)
  let itemKitDynamicGasTankAdvanced: int = 1533501495 // Kit (Portable Gas Tank Mk II)
  let itemKitDynamicGenerator: int = -732720413 // Kit (Portable Generator)
  let itemKitDynamicHydroponics: int = -1861154222 // Kit (Portable Hydroponics)
  let itemKitDynamicLiquidCanister: int = 375541286 // Kit (Portable Liquid Tank)
  let itemKitDynamicMKIILiquidCanister: int = -638019974 // Kit (Portable Liquid Tank Mk II)
  let itemKitElectronicsPrinter: int = -1181922382 // Kit (Electronics Printer)
  let itemKitElevator: int = -945806652 // Kit (Elevator)
  let itemKitEngineLarge: int = 755302726 // Kit (Engine Large)
  let itemKitEngineMedium: int = 1969312177 // Kit (Engine Medium)
  let itemKitEngineSmall: int = 19645163 // Kit (Engine Small)
  let itemKitEvaporationChamber: int = 1587787610 // Kit (Phase Change Device)
  let itemKitFlagODA: int = 1701764190 // Kit (ODA Flag)
  let itemKitFridgeBig: int = -1168199498 // Kit (Fridge Large)
  let itemKitFridgeSmall: int = 1661226524 // Kit (Fridge Small)
  let itemKitFurnace: int = -806743925 // Kit (Furnace)
  let itemKitFurniture: int = 1162905029 // Kit (Furniture)
  let itemKitGasGenerator: int = 377745425 // Kit (Gas Fuel Generator)
  let itemKitGrowLight: int = 341030083 // Kit (Grow Light)
  let itemKitHarvie: int = -1022693454 // Kit (Harvie)
  let itemKitHeatExchanger: int = -1710540039 // Kit Heat Exchanger
  let itemKitHorizontalAutoMiner: int = 844391171 // Kit (OGRE)
  let itemKitHydraulicPipeBender: int = -2098556089 // Kit (Hydraulic Pipe Bender)
  let itemKitHydroponicAutomated: int = -927931558 // Kit (Automated Hydroponics)
  let itemKitHydroponicStation: int = 2057179799 // Kit (Hydroponic Station)
  let itemKitIceCrusher: int = 288111533 // Kit (Ice Crusher)
  let itemKitInsulatedLiquidPipe: int = 2067655311 // Kit (Insulated Liquid Pipe)
  let itemKitInsulatedPipe: int = 452636699 // Kit (Insulated Pipe)
  let itemKitInteriorDoors: int = 1935945891 // Kit (Interior Doors)
  let itemKitLadder: int = 489494578 // Kit (Ladder)
  let itemKitLandingPad: int = -1793485995 // Kit (Landing Pad)
  let itemKitLandingPadAtmos: int = 1817007843 // Kit (Landing Pad Atmospherics)
  let itemKitLandingPadBasic: int = 293581318 // Kit (Landing Pad Basic)
  let itemKitLandingPadWaypoint: int = -1267511065 // Kit (Landing Pad Runway)
  let itemKitLargeDirectHeatExchanger: int = 450164077 // Kit (Large Direct Heat Exchanger)
  let itemKitLargeExtendableRadiator: int = 847430620 // Kit (Large Extendable Radiator)
  let itemKitLargeSatelliteDish: int = -2039971217 // Kit (Large Satellite Dish)
  let itemKitLiquidRegulator: int = 1951126161 // Kit (Liquid Regulator)
  let itemKitLiquidTank: int = -799849305 // Kit (Liquid Tank)
  let itemKitLiquidTankInsulated: int = 617773453 // Kit (Insulated Liquid Tank)
  let itemKitLiquidTurboVolumePump: int = -1805020897 // Kit (Turbo Volume Pump - Liquid)
  let itemKitLocker: int = 882301399 // Kit (Locker)
  let itemKitLogicCircuit: int = 1512322581 // Kit (IC Housing)
  let itemKitLogicInputOutput: int = 1997293610 // Kit (Logic I/O)
  let itemKitLogicMemory: int = -2098214189 // Kit (Logic Memory)
  let itemKitLogicProcessor: int = 220644373 // Kit (Logic Processor)
  let itemKitLogicSwitch: int = 124499454 // Kit (Logic Switch)
  let itemKitLogicTransmitter: int = 1005397063 // Kit (Logic Transmitter)
  let itemKitMotherShipCore: int = -344968335 // Kit (Mothership)
  let itemKitMusicMachines: int = -2038889137 // Kit (Music Machines)
  let itemKitPassiveLargeRadiatorGas: int = -1752768283 // Kit (Medium Radiator)
  let itemKitPassiveLargeRadiatorLiquid: int = 1453961898 // Kit (Medium Radiator Liquid)
  let itemKitPassthroughHeatExchanger: int = 636112787 // Kit (CounterFlow Heat Exchanger)
  let itemKitPictureFrame: int = -2062364768 // Kit Picture Frame
  let itemKitPipe: int = -1619793705 // Kit (Pipe)
  let itemKitPipeLiquid: int = -1166461357 // Kit (Liquid Pipe)
  let itemKitPipeOrgan: int = -827125300 // Kit (Pipe Organ)
  let itemKitPipeRadiator: int = 920411066 // Kit (Pipe Radiator)
  let itemKitPipeRadiatorLiquid: int = -1697302609 // Kit (Pipe Radiator Liquid)
  let itemKitPipeUtility: int = 1934508338 // Kit (Pipe Utility Gas)
  let itemKitPipeUtilityLiquid: int = 595478589 // Kit (Pipe Utility Liquid)
  let itemKitPlanter: int = 119096484 // Kit (Planter)
  let itemKitPoweredVent: int = 2015439334 // Kit (Powered Vent)
  let itemKitPowerTransmitter: int = 291368213 // Kit (Power Transmitter)
  let itemKitPowerTransmitterOmni: int = -831211676 // Kit (Power Transmitter Omni)
  let itemKitPressurePlate: int = 123504691 // Kit (Trigger Plate)
  let itemKitRailing: int = 750176282 // Kit (Railing)
  let itemKitRecycler: int = 849148192 // Kit (Recycler)
  let itemKitRegulator: int = 1181371795 // Kit (Pressure Regulator)
  let itemKitReinforcedWindows: int = 1459985302 // Reinforced Windows (Kit)
  let itemKitResearchMachine: int = 724776762 // Kit Research Machine
  let itemKitRespawnPointWallMounted: int = 1574688481 // Kit (Respawn)
  let itemKitRoverFrame: int = 1827215803 // Kit (Rover Frame)
  let itemKitRoverMKI: int = 197243872 // Kit (Rover Mk I)
  let itemKitSatelliteDish: int = 178422810 // Kit (Medium Satellite Dish)
  let itemKitSDBHopper: int = 323957548 // Kit (SDB Hopper)
  let itemKitSecurityPrinter: int = 578078533 // Kit (Security Printer)
  let itemKitSensor: int = -1776897113 // Kit (Sensors)
  let itemKitSign: int = 529996327 // Kit (Sign)
  let itemKitSleeper: int = 326752036 // Kit (Sleeper)
  let itemKitSmallDirectHeatExchanger: int = -1332682164 // Kit (Small Direct Heat Exchanger)
  let itemKitSmallSatelliteDish: int = 1960952220 // Kit (Small Satellite Dish)
  let itemKitSolarPanel: int = -1924492105 // Kit (Solar Panel)
  let itemKitSolarPanelBasic: int = 844961456 // Kit (Solar Panel Basic)
  let itemKitSolarPanelBasicReinforced: int = -528695432 // Kit (Solar Panel Basic Heavy)
  let itemKitSolarPanelReinforced: int = -364868685 // Kit (Solar Panel Heavy)
  let itemKitSolidGenerator: int = 1293995736 // Kit (Solid Generator)
  let itemKitSorter: int = 969522478 // Kit (Sorter)
  let itemKitSpeaker: int = -126038526 // Kit (Speaker)
  let itemKitStacker: int = 1013244511 // Kit (Stacker)
  let itemKitStairs: int = 170878959 // Kit (Stairs)
  let itemKitStandardChute: int = 2133035682 // Kit (Powered Chutes)
  let itemKitStirlingEngine: int = -1821571150 // Kit (Stirling Engine)
  let itemKitSuitStorage: int = 1088892825 // Kit (Suit Storage)
  let itemKitTables: int = -1361598922 // Kit (Tables)
  let itemKitTank: int = 771439840 // Kit (Tank)
  let itemKitTankInsulated: int = 1021053608 // Kit (Tank Insulated)
  let itemKitToolManufactory: int = 529137748 // Kit (Tool Manufactory)
  let itemKitTransformer: int = -453039435 // Kit Transformer (Large)
  let itemKitTransformerSmall: int = 665194284 // Kit (Transformer)
  let itemKitTurbineGenerator: int = -1590715731 // Kit (Turbine Generator)
  let itemKitTurboVolumePump: int = -1248429712 // Kit (Turbo Volume Pump - Gas)
  let itemKitUprightWindTurbine: int = -1798044015 // Kit (Upright Wind Turbine)
  let itemKitVendingMachine: int = -2038384332 // Kit (Vending Machine)
  let itemKitVendingMachineRefrigerated: int = -1867508561 // Kit (Vending Machine Refrigerated)
  let itemKitWall: int = -1826855889 // Kit (Wall)
  let itemKitWallArch: int = 1625214531 // Kit (Arched Wall)
  let itemKitWallFlat: int = -846838195 // Kit (Flat Wall)
  let itemKitWallGeometry: int = -784733231 // Kit (Geometric Wall)
  let itemKitWallIron: int = -524546923 // Kit (Iron Wall)
  let itemKitWallPadded: int = -821868990 // Kit (Padded Wall)
  let itemKitWaterBottleFiller: int = 159886536 // Kit (Water Bottle Filler)
  let itemKitWeatherStation: int = 337505889 // Kit (Weather Station)
  let itemKitWindowShutter: int = 1779979754 // Kit (Window Shutter)
  let itemKitWindTurbine: int = -868916503 // Kit (Wind Turbine)
  let itemLabeller: int = -743968726 // Labeller
  let itemLaptop: int = 141535121 // Laptop
  let itemLeadIngot: int = 2134647745 // Ingot (Lead)
  let itemLeadOre: int = -190236170 // Ore (Lead)
  let itemLightSword: int = 1949076595 // Light Sword
  let itemLiquidCanisterEmpty: int = -185207387 // Liquid Canister
  let itemLiquidCanisterSmart: int = 777684475 // Liquid Canister (Smart)
  let itemLiquidDrain: int = 2036225202 // Kit (Liquid Drain)
  let itemLiquidPipeAnalyzer: int = 226055671 // Kit (Liquid Pipe Analyzer)
  let itemLiquidPipeHeater: int = -248475032 // Pipe Heater Kit (Liquid)
  let itemLiquidPipeValve: int = -2126113312 // Kit (Liquid Pipe Valve)
  let itemLiquidPipeVolumePump: int = -2106280569 // Kit (Liquid Volume Pump)
  let itemLiquidTankStorage: int = 2037427578 // Kit (Liquid Canister Storage)
  let itemMarineBodyArmor: int = 1399098998 // Marine Armor
  let itemMarineHelmet: int = 1073631646 // Marine Helmet
  let itemMilk: int = 1327248310 // Milk
  let itemMiningBackPack: int = -1650383245 // Mining Backpack
  let itemMiningBelt: int = -676435305 // Mining Belt
  let itemMiningBeltMKII: int = 1470787934 // Mining Belt MK II
  let itemMiningCharge: int = 15829510 // Mining Charge
  let itemMiningDrill: int = 1055173191 // Mining Drill
  let itemMiningDrillHeavy: int = -1663349918 // Mining Drill (Heavy)
  let itemMKIIAngleGrinder: int = 240174650 // Mk II Angle Grinder
  let itemMKIIArcWelder: int = -2061979347 // Mk II Arc Welder
  let itemMKIICrowbar: int = 1440775434 // Mk II Crowbar
  let itemMKIIDrill: int = 324791548 // Mk II Drill
  let itemMKIIDuctTape: int = 388774906 // Mk II Duct Tape
  let itemMKIIMiningDrill: int = -1875271296 // Mk II Mining Drill
  let itemMKIIScrewdriver: int = -2015613246 // Mk II Screwdriver
  let itemMkIIToolbelt: int = 1467558064 // Tool Belt MK II
  let itemMKIIWireCutters: int = -178893251 // Mk II Wire Cutters
  let itemMKIIWrench: int = 1862001680 // Mk II Wrench
  let itemMuffin: int = -1864982322 // Muffin
  let itemMushroom: int = 2044798572 // Mushroom
  let itemNickelIngot: int = -1406385572 // Ingot (Nickel)
  let itemNickelOre: int = 1830218956 // Ore (Nickel)
  let itemNitrice: int = -1499471529 // Ice (Nitrice)
  let itemNVG: int = 982514123 // Night Vision Goggles
  let itemOxite: int = -1805394113 // Ice (Oxite)
  let itemPassiveVent: int = 238631271 // Passive Vent
  let itemPeaceLily: int = 2042955224 // Peace Lily
  let itemPickaxe: int = -913649823 // Pickaxe
  let itemPillHeal: int = 1118069417 // Pill (Medical)
  let itemPillStun: int = 418958601 // Pill (Paralysis)
  let itemPipeAnalyizer: int = -767597887 // Kit (Pipe Analyzer)
  let itemPipeCowl: int = -38898376 // Pipe Cowl
  let itemPipeDigitalValve: int = -1532448832 // Kit (Digital Valve)
  let itemPipeGasMixer: int = -1134459463 // Kit (Gas Mixer)
  let itemPipeHeater: int = -1751627006 // Pipe Heater Kit (Gas)
  let itemPipeLabel: int = 391769637 // Kit (Pipe Label)
  let itemPipeLiquidRadiator: int = -906521320 // Kit (Liquid Radiator)
  let itemPipeMeter: int = 1207939683 // Kit (Pipe Meter)
  let itemPipeRadiator: int = -1796655088 // Kit (Radiator)
  let itemPipeValve: int = 799323450 // Kit (Pipe Valve)
  let itemPipeVolumePump: int = -1766301997 // Kit (Volume Pump)
  let itemPlantEndothermic_Creative: int = -1159179557 // Endothermic Plant Creative
  let itemPlantEndothermic_Genepool1: int = 851290561 // Winterspawn (Alpha variant)
  let itemPlantEndothermic_Genepool2: int = -1414203269 // Winterspawn (Beta variant)
  let itemPlantSampler: int = 173023800 // Plant Sampler
  let itemPlantSwitchGrass: int = -532672323 // Switch Grass
  let itemPlantThermogenic_Creative: int = -1208890208 // Thermogenic Plant Creative
  let itemPlantThermogenic_Genepool1: int = -177792789 // Hades Flower (Alpha strain)
  let itemPlantThermogenic_Genepool2: int = 1819167057 // Hades Flower (Beta strain)
  let itemPlasticSheets: int = 662053345 // Plastic Sheets
  let itemPotato: int = 1929046963 // Potato
  let itemPotatoBaked: int = -2111886401 // Baked Potato
  let itemPowerConnector: int = 839924019 // Kit (Power Connector)
  let itemPumpkin: int = 1277828144 // Pumpkin
  let itemPumpkinPie: int = 62768076 // Pumpkin Pie
  let itemPumpkinSoup: int = 1277979876 // Pumpkin Soup
  let itemPureIce: int = -1616308158 // Pure Ice Water
  let itemPureIceCarbonDioxide: int = -1251009404 // Pure Ice Carbon Dioxide
  let itemPureIceLiquidCarbonDioxide: int = -1715945725 // Pure Ice Liquid Carbon Dioxide
  let itemPureIceLiquidNitrogen: int = 1674576569 // Pure Ice Liquid Nitrogen
  let itemPureIceLiquidNitrous: int = 1428477399 // Pure Ice Liquid Nitrous
  let itemPureIceLiquidOxygen: int = 541621589 // Pure Ice Liquid Oxygen
  let itemPureIceLiquidPollutant: int = -1748926678 // Pure Ice Liquid Pollutant
  let itemPureIceLiquidVolatiles: int = -1306628937 // Pure Ice Liquid Volatiles
  let itemPureIceNitrogen: int = -1708395413 // Pure Ice Nitrogen
  let itemPureIceNitrous: int = 386754635 // Pure Ice NitrousOxide
  let itemPureIceOxygen: int = -1150448260 // Pure Ice Oxygen
  let itemPureIcePollutant: int = -1755356 // Pure Ice Pollutant
  let itemPureIceSteam: int = -874791066 // Pure Ice Steam
  let itemPureIceVolatiles: int = -633723719 // Pure Ice Volatiles
  let itemReagentMix: int = -1641500434 // Reagent Mix
  let itemRemoteDetonator: int = 678483886 // Remote Detonator
  let itemResearchCapsuleGreen: int = -1352732550 // Research Capsule Green
  let itemResearchCapsuleRed: int = 954947943 // Research Capsule Red
  let itemResearchCapsuleYellow: int = 750952701 // Research Capsule Yellow
  let itemRice: int = 658916791 // Rice
  let itemRoadFlare: int = 871811564 // Road Flare
  let itemRTG: int = 495305053 // Kit (Creative RTG)
  let itemRTGSurvival: int = 1817645803 // Kit (RTG)
  let itemScanner: int = 1661270830 // Handheld Scanner
  let itemScrewdriver: int = 687940869 // Screwdriver
  let itemSecurityCamera: int = -1981101032 // Security Camera
  let itemSensorLenses: int = -1176140051 // Sensor Lenses
  let itemSensorProcessingUnitOreScanner: int = -1219128491 // Sensor Processing Unit (Ore Scanner)
  let itemSiliconIngot: int = -290196476 // Ingot (Silicon)
  let itemSiliconOre: int = 1103972403 // Ore (Silicon)
  let itemSilverIngot: int = -929742000 // Ingot (Silver)
  let itemSilverOre: int = -916518678 // Ore (Silver)
  let itemSolderIngot: int = -82508479 // Ingot (Solder)
  let itemSolidFuel: int = -365253871 // Solid Fuel (Hydrocarbon)
  let itemSoundCartridgeBass: int = -1883441704 // Sound Cartridge Bass
  let itemSoundCartridgeDrums: int = -1901500508 // Sound Cartridge Drums
  let itemSoundCartridgeLeads: int = -1174735962 // Sound Cartridge Leads
  let itemSoundCartridgeSynth: int = -1971419310 // Sound Cartridge Synth
  let itemSoybean: int = 1924673028 // Soybean
  let itemSoyOil: int = 1387403148 // Soy Oil
  let itemSpaceCleaner: int = -1737666461 // Space Cleaner
  let itemSpaceHelmet: int = 714830451 // Space Helmet
  let itemSpacepack: int = -1260618380 // Spacepack
  let itemSprayCanBlack: int = -688107795 // Spray Paint (Black)
  let itemSprayCanBlue: int = -498464883 // Spray Paint (Blue)
  let itemSprayCanBrown: int = 845176977 // Spray Paint (Brown)
  let itemSprayCanGreen: int = -1880941852 // Spray Paint (Green)
  let itemSprayCanGrey: int = -1645266981 // Spray Paint (Grey)
  let itemSprayCanKhaki: int = 1918456047 // Spray Paint (Khaki)
  let itemSprayCanOrange: int = -158007629 // Spray Paint (Orange)
  let itemSprayCanPink: int = 1344257263 // Spray Paint (Pink)
  let itemSprayCanPurple: int = 30686509 // Spray Paint (Purple)
  let itemSprayCanRed: int = 1514393921 // Spray Paint (Red)
  let itemSprayCanWhite: int = 498481505 // Spray Paint (White)
  let itemSprayCanYellow: int = 995468116 // Spray Paint (Yellow)
  let itemSprayGun: int = 1289723966 // Spray Gun
  let itemSteelFrames: int = -1448105779 // Steel Frames
  let itemSteelIngot: int = -654790771 // Ingot (Steel)
  let itemSteelSheets: int = 38555961 // Steel Sheets
  let itemStelliteGlassSheets: int = -2038663432 // Stellite Glass Sheets
  let itemStelliteIngot: int = -1897868623 // Ingot (Stellite)
  let itemTablet: int = -229808600 // Handheld Tablet
  let itemTerrainManipulator: int = 111280987 // Terrain Manipulator
  let itemTomato: int = -998592080 // Tomato
  let itemTomatoSoup: int = 688734890 // Tomato Soup
  let itemToolBelt: int = -355127880 // Tool Belt
  let itemTropicalPlant: int = -800947386 // Tropical Lily
  let itemUraniumOre: int = -1516581844 // Ore (Uranium)
  let itemVolatiles: int = 1253102035 // Ice (Volatiles)
  let itemWallCooler: int = -1567752627 // Kit (Wall Cooler)
  let itemWallHeater: int = 1880134612 // Kit (Wall Heater)
  let itemWallLight: int = 1108423476 // Kit (Lights)
  let itemWaspaloyIngot: int = 156348098 // Ingot (Waspaloy)
  let itemWaterBottle: int = 107741229 // Water Bottle
  let itemWaterPipeDigitalValve: int = 309693520 // Kit (Liquid Digital Valve)
  let itemWaterPipeMeter: int = -90898877 // Kit (Liquid Pipe Meter)
  let itemWaterWallCooler: int = -1721846327 // Kit (Liquid Wall Cooler)
  let itemWearLamp: int = -598730959 // Headlamp
  let itemWeldingTorch: int = -2066892079 // Welding Torch
  let itemWheat: int = -1057658015 // Wheat
  let itemWireCutters: int = 1535854074 // Wire Cutters
  let itemWirelessBatteryCellExtraLarge: int = -504717121 // Wireless Battery Cell Extra Large
  let itemWreckageAirConditioner1: int = -1826023284 // Wreckage Air Conditioner
  let itemWreckageAirConditioner2: int = 169888054 // Wreckage Air Conditioner
  let itemWreckageHydroponicsTray1: int = -310178617 // Wreckage Hydroponics Tray
  let itemWreckageLargeExtendableRadiator01: int = -997763 // Wreckage Large Extendable Radiator
  let itemWreckageStructureRTG1: int = 391453348 // Wreckage Structure RTG
  let itemWreckageStructureWeatherStation001: int = -834664349 // Wreckage Structure Weather Station
  let itemWreckageStructureWeatherStation002: int = 1464424921 // Wreckage Structure Weather Station
  let itemWreckageStructureWeatherStation003: int = 542009679 // Wreckage Structure Weather Station
  let itemWreckageStructureWeatherStation004: int = -1104478996 // Wreckage Structure Weather Station
  let itemWreckageStructureWeatherStation005: int = -919745414 // Wreckage Structure Weather Station
  let itemWreckageStructureWeatherStation006: int = 1344576960 // Wreckage Structure Weather Station
  let itemWreckageStructureWeatherStation007: int = 656649558 // Wreckage Structure Weather Station
  let itemWreckageStructureWeatherStation008: int = -1214467897 // Wreckage Structure Weather Station
  let itemWreckageTurbineGenerator1: int = -1662394403 // Wreckage Turbine Generator
  let itemWreckageTurbineGenerator2: int = 98602599 // Wreckage Turbine Generator
  let itemWreckageTurbineGenerator3: int = 1927790321 // Wreckage Turbine Generator
  let itemWreckageWallCooler1: int = -1682930158 // Wreckage Wall Cooler
  let itemWreckageWallCooler2: int = 45733800 // Wreckage Wall Cooler
  let itemWrench: int = -1886261558 // Wrench
  let kitAutomatedRocketAutomationModule: int = -1333836038 // Kit (Automated Rocket Automation Module)
  let kitAutomatedRocketCouplingModule: int = -125973341 // Kit (Automated Rocket Coupling Module)
  let kitAutomatedRocketGasMiningModule: int = 1545333914 // Kit (Automated Rocket Gas Mining Module)
  let kitAutomatedRocketIceMiningModule: int = -755852927 // Kit (Automated Rocket Ice Mining Module)
  let kitAutomatedRocketOreMiningModule: int = 301584830 // Kit (Automated Rocket Ore Mining Module)
  let kitAutomatedRocketSalvageModule: int = -1845774508 // Kit (Automated Rocket Salvage Module)
  let kitAutomatedRocketSiloModule: int = -90221115 // Kit (Automated Rocket Silo Module)
  let kitInsulatedTankConnectorLiquid: int = -122188311 // Kit (Insulated Tank Connector Liquid)
  let kitLaunchPad: int = -1538229217 // Kit (Launch Pad)
  let kitLiquidTankConnector: int = -1579112308 // Kit (Liquid Tank Connector)
  let kitLowVolumeLiquidPipe: int = 1709456101 // Kit (Low Volume Liquid Pipe)
  let kitLowVolumePipe: int = -94545890 // Kit (Low Volume Pipe)
  let kitModularRocketCargo: int = -347156845 // Kit (Modular Rocket Cargo)
  let kitModularRocketCommand: int = 853741262 // Kit (Modular Rocket Command)
  let kitModularRocketEngine: int = -34763297 // Kit (Modular Rocket Engine)
  let kitModularRocketFueltank: int = -1838947287 // Kit (Modular Rocket Fueltank)
  let kitTankConnector: int = -1782380726 // Kit (Tank Connector)
  let kitchenTableShort: int = -1427415566 // Kitchen Table (Short)
  let kitchenTableSimpleShort: int = -78099334 // Kitchen Table (Simple Short)
  let kitchenTableSimpleTall: int = -1068629349 // Kitchen Table (Simple Tall)
  let kitchenTableTall: int = -1386237782 // Kitchen Table (Tall)
  let kitSDBSilo: int = 1932952652 // Kit (SDB Silo)
  let kitStructureCombustionCentrifuge: int = 231903234 // Kit (Combustion Centrifuge)
  let lander: int = 1605130615 // Lander
  let landingPad: int = -1309237526 // Landing Pad
  let landingpad_2x2CenterPiece01: int = -1295222317 // Landingpad 2x2 Center Piece
  let landingpad_CenterPiece01: int = 1070143159 // Landingpad Center
  let landingpad_CrossPiece: int = 1101296153 // Landingpad Cross
  let landingpad_DataConnectionPiece: int = -2066405918 // Landingpad Data And Power
  let landingpad_DiagonalPiece01: int = 977899131 // Landingpad Diagonal
  let landingpad_GasConnectorInwardPiece: int = 817945707 // Landingpad Gas Input
  let landingpad_GasConnectorOutwardPiece: int = -1100218307 // Landingpad Gas Output
  let landingpad_GasCylinderTankPiece: int = 170818567 // Landingpad Gas Storage
  let landingpad_LiquidConnectorInwardPiece: int = -1216167727 // Landingpad Liquid Input
  let landingpad_LiquidConnectorOutwardPiece: int = -1788929869 // Landingpad Liquid Output
  let landingpad_StraightPiece01: int = -976273247 // Landingpad Straight
  let landingpad_TaxiPieceCorner: int = -1872345847 // Landingpad Taxi Corner
  let landingpad_TaxiPieceHold: int = 146051619 // Landingpad Taxi Hold
  let landingpad_TaxiPieceStraight: int = -1477941080 // Landingpad Taxi Straight
  let landingpad_ThreshholdPiece: int = -1514298582 // Landingpad Threshhold
  let liquidRocketEngineBasic: int = -1748149715 // Liquid Rocket Engine Basic
  let logicStepSequencer8: int = 1531272458 // Logic Step Sequencer
  let lowVolumeLiquidPipe3WayJunction: int = 338145176 // Low Volume Liquid Pipe (3-Way Junction)
  let lowVolumeLiquidPipe4WayJunction: int = -1975305669 // Low Volume Liquid Pipe (4-Way Junction)
  let lowVolumeLiquidPipe5WayJunction: int = -45872467 // Low Volume Liquid Pipe (5-Way Junction)
  let lowVolumeLiquidPipe6WayJunction: int = 1682791191 // Low Volume Liquid Pipe (6-Way Junction)
  let lowVolumePipe3WayJunction: int = -1421666624 // Low Volume Pipe (3-Way Junction)
  let lowVolumePipe4WayJunction: int = 891781987 // Low Volume Pipe (4-Way Junction)
  let lowVolumePipe5WayJunction: int = 1109439477 // Low Volume Pipe (5-Way Junction)
  let lowVolumePipe6WayJunction: int = -618012081 // Low Volume Pipe (6-Way Junction)
  let meteorite: int = -99064335 // Meteorite
  let modularRocketCargo: int = -452398260 // Modular Rocket Cargo
  let modularRocketCommand: int = 1814795593 // Modular Rocket Command
  let modularRocketEngine: int = -342948697 // Modular Rocket Engine
  let modularRocketFueltank: int = -505333199 // Modular Rocket Fueltank
  let modularRocketLaunchPad: int = 373721410 // Modular Rocket Launch Pad
  let monsterEgg: int = -1667675295 // <N:EN:MonsterEgg>
  let motherboardComms: int = -337075633 // Communications Motherboard
  let motherboardLogic: int = 502555944 // Logic Motherboard
  let motherboardMissionControl: int = -127121474 // <N:EN:MotherboardMissionControl>
  let motherboardProgrammableChip: int = -161107071 // IC Editor Motherboard
  let motherboardSorter: int = -1908268220 // Sorter Motherboard
  let mothershipCore: int = -1930442922 // Mothership Core
  let npcChick: int = 155856647 // Chick
  let npcChicken: int = 399074198 // Chicken
  let oneWayValveGas: int = 1580412404 // One Way Valve (Gas)
  let oneWayValveLiquid: int = -782453061 // One Way Valve (Liquid)
  let passiveSpeaker: int = 248893646 // Passive Speaker
  let pipeBenderMod: int = 443947415 // Pipe Bender Mod
  let portableComposter: int = -1958705204 // Portable Composter
  let portableSolarPanel: int = 2043318949 // Portable Solar Panel
  let railingElegant01: int = 399661231 // Railing Elegant (Type 1)
  let railingElegant02: int = -1898247915 // Railing Elegant (Type 2)
  let railingIndustrial02: int = -2072792175 // Railing Industrial (Type 2)
  let reagentColorBlue: int = 980054869 // Color Dye (Blue)
  let reagentColorGreen: int = 120807542 // Color Dye (Green)
  let reagentColorOrange: int = -400696159 // Color Dye (Orange)
  let reagentColorRed: int = 1998377961 // Color Dye (Red)
  let reagentColorYellow: int = 635208006 // Color Dye (Yellow)
  let researchCapsuleBlue: int = 819096942 // Research Capsule Blue
  let respawnPoint: int = -788672929 // Respawn Point
  let respawnPointWallMounted: int = -491247370 // Respawn Point (Mounted)
  let robot: int = 434786784 // AIMeE Bot
  let rover_MkI: int = -2049946335 // Rover MkI
  let rover_MkI_build_states: int = 861674123 // Rover MKI
  let roverCargo: int = 350726273 // Rover (Cargo)
  let rTG: int = 1905352762 // RTG
  let seedBag_Corn: int = -1290755415 // Corn Seeds
  let seedBag_Fern: int = -1990600883 // Fern Seeds
  let seedBag_Mushroom: int = 311593418 // Mushroom Seeds
  let seedBag_Potato: int = 1005571172 // Potato Seeds
  let seedBag_Pumpkin: int = 1423199840 // Pumpkin Seeds
  let seedBag_Rice: int = -1691151239 // Rice Seeds
  let seedBag_Soybean: int = 1783004244 // Soybean Seeds
  let seedBag_Switchgrass: int = 488360169 // Switchgrass Seed
  let seedBag_Tomato: int = -1922066841 // Tomato Seeds
  let seedBag_Wheet: int = -654756733 // Wheat Seeds
  let sMGMagazine: int = -256607540 // SMG Magazine
  let spaceShuttle: int = -1991297271 // Space Shuttle
  let stopWatch: int = -1527229051 // Stop Watch
  let structureActiveVent: int = -1129453144 // Active Vent
  let structureAdvancedComposter: int = 446212963 // Advanced Composter
  let structureAdvancedFurnace: int = 545937711 // Advanced Furnace
  let structureAdvancedPackagingMachine: int = -463037670 // Advanced Packaging Machine
  let structureAirConditioner: int = -2087593337 // Air Conditioner
  let structureAirlock: int = -2105052344 // Airlock
  let structureAirlockGate: int = 1736080881 // Small Hangar Door
  let structureAngledBench: int = 1811979158 // Bench (Angled)
  let structureArcFurnace: int = -247344692 // Arc Furnace
  let structureAreaPowerControl: int = 1999523701 // Area Power Control
  let structureAreaPowerControlReversed: int = -1032513487 // Area Power Control
  let structureAutolathe: int = 336213101 // Autolathe
  let structureAutomatedOven: int = -1672404896 // Automated Oven
  let structureAutoMinerSmall: int = 7274344 // Autominer (Small)
  let structureBackLiquidPressureRegulator: int = 2099900163 // Liquid Back Volume Regulator
  let structureBackPressureRegulator: int = -1149857558 // Back Pressure Regulator
  let structureBasketHoop: int = -1613497288 // Basket Hoop
  let structureBattery: int = -400115994 // Station Battery
  let structureBatteryCharger: int = 1945930022 // Battery Cell Charger
  let structureBatteryChargerSmall: int = -761772413 // Battery Charger Small
  let structureBatteryLarge: int = -1388288459 // Station Battery (Large)
  let structureBeacon: int = -188177083 // Beacon
  let structureBench: int = -2042448192 // Powered Bench
  let structureBench1: int = 406745009 // Bench (Counter Style)
  let structureBench2: int = -2127086069 // Bench (High Tech Style)
  let structureBench3: int = -164622691 // Bench (Frame Style)
  let structureBench4: int = 1750375230 // Bench (Workbench Style)
  let structureBlastDoor: int = 337416191 // Blast Door
  let structureBlockBed: int = 697908419 // Block Bed
  let structureBlocker: int = 378084505 // Blocker
  let structureCableAnalysizer: int = 1036015121 // Cable Analyzer
  let structureCableCorner: int = -889269388 // Cable (Corner)
  let structureCableCorner3: int = 980469101 // Cable (3-Way Corner)
  let structureCableCorner3Burnt: int = 318437449 // Burnt Cable (3-Way Corner)
  let structureCableCorner3HBurnt: int = 2393826 // <N:EN:StructureCableCorner3HBurnt>
  let structureCableCorner4: int = -1542172466 // Cable (4-Way Corner)
  let structureCableCorner4Burnt: int = 268421361 // Burnt Cable (4-Way Corner)
  let structureCableCorner4HBurnt: int = -981223316 // Burnt Heavy Cable (4-Way Corner)
  let structureCableCornerBurnt: int = -177220914 // Burnt Cable (Corner)
  let structureCableCornerH: int = -39359015 // Heavy Cable (Corner)
  let structureCableCornerH3: int = -1843379322 // Heavy Cable (3-Way Corner)
  let structureCableCornerH4: int = 205837861 // Heavy Cable (4-Way Corner)
  let structureCableCornerHBurnt: int = 1931412811 // Burnt Cable (Corner)
  let structureCableFuse100k: int = 281380789 // Fuse (100kW)
  let structureCableFuse1k: int = -1103727120 // Fuse (1kW)
  let structureCableFuse50k: int = -349716617 // Fuse (50kW)
  let structureCableFuse5k: int = -631590668 // Fuse (5kW)
  let structureCableJunction: int = -175342021 // Cable (Junction)
  let structureCableJunction4: int = 1112047202 // Cable (4-Way Junction)
  let structureCableJunction4Burnt: int = -1756896811 // Burnt Cable (4-Way Junction)
  let structureCableJunction4HBurnt: int = -115809132 // Burnt Cable (4-Way Junction)
  let structureCableJunction5: int = 894390004 // Cable (5-Way Junction)
  let structureCableJunction5Burnt: int = 1545286256 // Burnt Cable (5-Way Junction)
  let structureCableJunction6: int = -1404690610 // Cable (6-Way Junction)
  let structureCableJunction6Burnt: int = -628145954 // Burnt Cable (6-Way Junction)
  let structureCableJunction6HBurnt: int = 1854404029 // Burnt Cable (6-Way Junction)
  let structureCableJunctionBurnt: int = -1620686196 // Burnt Cable (Junction)
  let structureCableJunctionH: int = 469451637 // Heavy Cable (3-Way Junction)
  let structureCableJunctionH4: int = -742234680 // Heavy Cable (4-Way Junction)
  let structureCableJunctionH5: int = -1530571426 // Heavy Cable (5-Way Junction)
  let structureCableJunctionH5Burnt: int = 1701593300 // Burnt Heavy Cable (5-Way Junction)
  let structureCableJunctionH6: int = 1036780772 // Heavy Cable (6-Way Junction)
  let structureCableJunctionHBurnt: int = -341365649 // Burnt Cable (Junction)
  let structureCableStraight: int = 605357050 // Cable (Straight)
  let structureCableStraightBurnt: int = -1196981113 // Burnt Cable (Straight)
  let structureCableStraightH: int = -146200530 // Heavy Cable (Straight)
  let structureCableStraightHBurnt: int = 2085762089 // Burnt Cable (Straight)
  let structureCamera: int = -342072665 // Camera
  let structureCentrifuge: int = 690945935 // Centrifuge
  let structureChair: int = 1167659360 // Chair
  let structureChairBacklessDouble: int = 1944858936 // Chair (Backless Double)
  let structureChairBacklessSingle: int = 1672275150 // Chair (Backless Single)
  let structureChairBoothCornerLeft: int = -367720198 // Chair (Booth Corner Left)
  let structureChairBoothMiddle: int = 1640720378 // Chair (Booth Middle)
  let structureChairRectangleDouble: int = -1152812099 // Chair (Rectangle Double)
  let structureChairRectangleSingle: int = -1425428917 // Chair (Rectangle Single)
  let structureChairThickDouble: int = -1245724402 // Chair (Thick Double)
  let structureChairThickSingle: int = -1510009608 // Chair (Thick Single)
  let structureChuteBin: int = -850484480 // Chute Bin
  let structureChuteCorner: int = 1360330136 // Chute (Corner)
  let structureChuteDigitalFlipFlopSplitterLeft: int = -810874728 // Chute Digital Flip Flop Splitter Left
  let structureChuteDigitalFlipFlopSplitterRight: int = 163728359 // Chute Digital Flip Flop Splitter Right
  let structureChuteDigitalValveLeft: int = 648608238 // Chute Digital Valve Left
  let structureChuteDigitalValveRight: int = -1337091041 // Chute Digital Valve Right
  let structureChuteFlipFlopSplitter: int = -1446854725 // Chute Flip Flop Splitter
  let structureChuteInlet: int = -1469588766 // Chute Inlet
  let structureChuteJunction: int = -611232514 // Chute (Junction)
  let structureChuteOutlet: int = -1022714809 // Chute Outlet
  let structureChuteOverflow: int = 225377225 // Chute Overflow
  let structureChuteStraight: int = 168307007 // Chute (Straight)
  let structureChuteValve: int = 434875271 // Chute Valve
  let structureChuteWindow: int = -607241919 // Chute (Window)
  let structureCircuitHousing: int = -128473777 // IC Housing
  let structureCombustionCentrifuge: int = 1238905683 // Combustion Centrifuge
  let structureCompositeCladdingAngled: int = -1513030150 // Composite Cladding (Angled)
  let structureCompositeCladdingAngledCorner: int = -69685069 // Composite Cladding (Angled Corner)
  let structureCompositeCladdingAngledCornerInner: int = -1841871763 // Composite Cladding (Angled Corner Inner)
  let structureCompositeCladdingAngledCornerInnerLong: int = -1417912632 // Composite Cladding (Angled Corner Inner Long)
  let structureCompositeCladdingAngledCornerInnerLongL: int = 947705066 // Composite Cladding (Angled Corner Inner Long L)
  let structureCompositeCladdingAngledCornerInnerLongR: int = -1032590967 // Composite Cladding (Angled Corner Inner Long R)
  let structureCompositeCladdingAngledCornerLong: int = 850558385 // Composite Cladding (Long Angled Corner)
  let structureCompositeCladdingAngledCornerLongR: int = -348918222 // Composite Cladding (Long Angled Mirrored Corner)
  let structureCompositeCladdingAngledLong: int = -387546514 // Composite Cladding (Long Angled)
  let structureCompositeCladdingCylindrical: int = 212919006 // Composite Cladding (Cylindrical)
  let structureCompositeCladdingCylindricalPanel: int = 1077151132 // Composite Cladding (Cylindrical Panel)
  let structureCompositeCladdingPanel: int = 1997436771 // Composite Cladding (Panel)
  let structureCompositeCladdingRounded: int = -259357734 // Composite Cladding (Rounded)
  let structureCompositeCladdingRoundedCorner: int = 1951525046 // Composite Cladding (Rounded Corner)
  let structureCompositeCladdingRoundedCornerInner: int = 110184667 // Composite Cladding (Rounded Corner Inner)
  let structureCompositeCladdingSpherical: int = 139107321 // Composite Cladding (Spherical)
  let structureCompositeCladdingSphericalCap: int = 534213209 // Composite Cladding (Spherical Cap)
  let structureCompositeCladdingSphericalCorner: int = 1751355139 // Composite Cladding (Spherical Corner)
  let structureCompositeDoor: int = -793837322 // Composite Door
  let structureCompositeFloorGrating: int = 324868581 // Composite Floor Grating
  let structureCompositeFloorGrating2: int = -895027741 // Composite Floor Grating  (Type 2)
  let structureCompositeFloorGrating3: int = -1113471627 // Composite Floor Grating  (Type 3)
  let structureCompositeFloorGrating4: int = 600133846 // Composite Floor Grating  (Type 4)
  let structureCompositeFloorGratingOpen: int = 2109695912 // Composite Floor Grating Open
  let structureCompositeFloorGratingOpenRotated: int = 882307910 // Composite Floor Grating Open Rotated
  let structureCompositeWall: int = 1237302061 // Composite Wall (Type 1)
  let structureCompositeWall02: int = 718343384 // Composite Wall (Type 2)
  let structureCompositeWall03: int = 1574321230 // Composite Wall (Type 3)
  let structureCompositeWall04: int = -1011701267 // Composite Wall (Type 4)
  let structureCompositeWindow: int = -2060571986 // Composite Window
  let structureCompositeWindowIron: int = -688284639 // Iron Window
  let structureComputer: int = -626563514 // Computer
  let structureCondensationChamber: int = 1420719315 // Condensation Chamber
  let structureCondensationValve: int = -965741795 // Condensation Valve
  let structureConsole: int = 235638270 // Console
  let structureConsoleDual: int = -722284333 // Console Dual
  let structureConsoleLED1x2: int = -53151617 // LED Display (Medium)
  let structureConsoleLED1x3: int = -1949054743 // LED Display (Large)
  let structureConsoleLED5: int = -815193061 // LED Display (Small)
  let structureConsoleMonitor: int = 801677497 // Console Monitor
  let structureControlChair: int = -1961153710 // Control Chair
  let structureCornerLocker: int = -1968255729 // Corner Locker
  let structureCrateMount: int = -733500083 // Container Mount
  let structureCryoTube: int = 1938254586 // CryoTube
  let structureCryoTubeHorizontal: int = 1443059329 // Cryo Tube Horizontal
  let structureCryoTubeVertical: int = -1381321828 // Cryo Tube Vertical
  let structureDaylightSensor: int = 1076425094 // Daylight Sensor
  let structureDeepMiner: int = 265720906 // Deep Miner
  let structureDigitalValve: int = -1280984102 // Digital Valve
  let structureDiode: int = 1944485013 // LED
  let structureDiodeSlide: int = 576516101 // Diode Slide
  let structureDockPortSide: int = -137465079 // Dock (Port Side)
  let structureElectrolyzer: int = -1668992663 // Electrolyzer
  let structureElectronicsPrinter: int = 1307165496 // Electronics Printer
  let structureElevatorLevelFront: int = -827912235 // Elevator Level
  let structureElevatorShaft: int = 826144419 // Elevator Shaft
  let structureEmergencyButton: int = 1668452680 // Important Button
  let structureEvaporationChamber: int = -1429782576 // Evaporation Chamber
  let structureExpansionValve: int = 195298587 // Expansion Valve
  let structureFiltration: int = -348054045 // Filtration
  let structureFlagSmall: int = -1529819532 // Small Flag
  let structureFlashingLight: int = -1535893860 // Flashing Light
  let structureFlatBench: int = 839890807 // Bench (Flat)
  let structureFloorDrain: int = 1048813293 // Passive Liquid Inlet
  let structureFrame: int = 1432512808 // Steel Frame
  let structureFrameCorner: int = -2112390778 // Steel Frame (Corner)
  let structureFrameCornerCut: int = 271315669 // Steel Frame (Corner Cut)
  let structureFrameIron: int = -1240951678 // Iron Frame
  let structureFrameSide: int = -302420053 // Steel Frame (Side)
  let structureFridgeBig: int = 958476921 // Fridge (Large)
  let structureFridgeSmall: int = 751887598 // Fridge Small
  let structureFurnace: int = 1947944864 // Furnace
  let structureGasGenerator: int = 1165997963 // Gas Fuel Generator
  let structureGasMixer: int = 2104106366 // Gas Mixer
  let structureGasSensor: int = -1252983604 // Gas Sensor
  let structureGasTankStorage: int = 1632165346 // Gas Tank Storage
  let structureGlassDoor: int = -324331872 // Glass Door
  let structureGrowLight: int = -1758710260 // Grow Light
  let structureHarvie: int = 958056199 // Harvie
  let structureHeatExchangeLiquidtoGas: int = 944685608 // Heat Exchanger - Liquid + Gas
  let structureHeatExchangerGastoGas: int = 21266291 // Heat Exchanger - Gas
  let structureHeatExchangerLiquidtoLiquid: int = -613784254 // Heat Exchanger - Liquid
  let structureHorizontalAutoMiner: int = 1070427573 // OGRE
  let structureHydraulicPipeBender: int = -1888248335 // Hydraulic Pipe Bender
  let structureHydroponicsStation: int = 1441767298 // Hydroponics Station
  let structureHydroponicsTray: int = 1464854517 // Hydroponics Tray
  let structureHydroponicsTrayData: int = -1841632400 // Hydroponics Device
  let structureIceCrusher: int = 443849486 // Ice Crusher
  let structureIgniter: int = 1005491513 // Igniter
  let structureInLineTankGas1x1: int = -1693382705 // In-Line Tank Small Gas
  let structureInLineTankGas1x2: int = 35149429 // In-Line Tank Gas
  let structureInLineTankLiquid1x1: int = 543645499 // In-Line Tank Small Liquid
  let structureInLineTankLiquid1x2: int = -1183969663 // In-Line Tank Liquid
  let structureInsulatedPipeCorner: int = -1967711059 // Insulated Pipe (Corner)
  let structureInsulatedPipeCrossJunction: int = -92778058 // Insulated Pipe (Cross Junction)
  let structureInsulatedPipeCrossJunction3: int = 1328210035 // Insulated Pipe (3-Way Junction)
  let structureInsulatedPipeCrossJunction4: int = -783387184 // Insulated Pipe (4-Way Junction)
  let structureInsulatedPipeCrossJunction5: int = -1505147578 // Insulated Pipe (5-Way Junction)
  let structureInsulatedPipeCrossJunction6: int = 1061164284 // Insulated Pipe (6-Way Junction)
  let structureInsulatedPipeLiquidCorner: int = 1713710802 // Insulated Liquid Pipe (Corner)
  let structureInsulatedPipeLiquidCrossJunction: int = 1926651727 // Insulated Liquid Pipe (3-Way Junction)
  let structureInsulatedPipeLiquidCrossJunction4: int = 363303270 // Insulated Liquid Pipe (4-Way Junction)
  let structureInsulatedPipeLiquidCrossJunction5: int = 1654694384 // Insulated Liquid Pipe (5-Way Junction)
  let structureInsulatedPipeLiquidCrossJunction6: int = -72748982 // Insulated Liquid Pipe (6-Way Junction)
  let structureInsulatedPipeLiquidStraight: int = 295678685 // Insulated Liquid Pipe (Straight)
  let structureInsulatedPipeLiquidTJunction: int = -532384855 // Insulated Liquid Pipe (T Junction)
  let structureInsulatedPipeStraight: int = 2134172356 // Insulated Pipe (Straight)
  let structureInsulatedPipeTJunction: int = -2076086215 // Insulated Pipe (T Junction)
  let structureInsulatedTankConnector: int = -31273349 // Insulated Tank Connector
  let structureInsulatedTankConnectorLiquid: int = -1602030414 // Insulated Tank Connector Liquid
  let structureInteriorDoorGlass: int = -2096421875 // Interior Door Glass
  let structureInteriorDoorPadded: int = 847461335 // Interior Door Padded
  let structureInteriorDoorPaddedThin: int = 1981698201 // Interior Door Padded Thin
  let structureInteriorDoorTriangle: int = -1182923101 // Interior Door Triangle
  let structureKlaxon: int = -828056979 // Klaxon Speaker
  let structureLadder: int = -415420281 // Ladder
  let structureLadderEnd: int = 1541734993 // Ladder End
  let structureLargeDirectHeatExchangeGastoGas: int = -1230658883 // Large Direct Heat Exchanger - Gas + Gas
  let structureLargeDirectHeatExchangeGastoLiquid: int = 1412338038 // Large Direct Heat Exchanger - Gas + Liquid
  let structureLargeDirectHeatExchangeLiquidtoLiquid: int = 792686502 // Large Direct Heat Exchange - Liquid + Liquid
  let structureLargeExtendableRadiator: int = -566775170 // Structure Large Extendable Radiator
  let structureLargeHangerDoor: int = -1351081801 // Large Hangar Door
  let structureLargeSatelliteDish: int = 1913391845 // Large Satellite Dish
  let structureLightLong: int = 797794350 // Wall Light (Long)
  let structureLightLongAngled: int = 1847265835 // Wall Light (Long Angled)
  let structureLightLongWide: int = 555215790 // Wall Light (Long Wide)
  let structureLightRound: int = 1514476632 // Light Round
  let structureLightRoundAngled: int = 1592905386 // Light Round (Angled)
  let structureLightRoundSmall: int = 1436121888 // Light Round (Small)
  let structureLiquidDrain: int = 1687692899 // Active Liquid Outlet
  let structureLiquidPipeAnalyzer: int = -2113838091 // Liquid Pipe Analyzer
  let structureLiquidPipeHeater: int = -287495560 // Pipe Heater (Liquid)
  let structureLiquidPipeRadiator: int = 2072805863 // Liquid Pipe Convection Radiator
  let structureLiquidPressureRegulator: int = 482248766 // Liquid Volume Regulator
  let structureLiquidTankBig: int = 1098900430 // Liquid Tank Big
  let structureLiquidTankBigInsulated: int = -1430440215 // Insulated Liquid Tank Big
  let structureLiquidTankSmall: int = 1988118157 // Liquid Tank Small
  let structureLiquidTankSmallInsulated: int = 608607718 // Insulated Liquid Tank Small
  let structureLiquidTankStorage: int = 1691898022 // Liquid Tank Storage
  let structureLiquidTurboVolumePump: int = -1051805505 // Turbo Volume Pump (Liquid)
  let structureLiquidValve: int = 1849974453 // Liquid Valve
  let structureLiquidVolumePump: int = -454028979 // Liquid Volume Pump
  let structureLockerSmall: int = -647164662 // Locker (Small)
  let structureLogicBatchReader: int = 264413729 // Batch Reader
  let structureLogicBatchSlotReader: int = 436888930 // Batch Slot Reader
  let structureLogicBatchWriter: int = 1415443359 // Batch Writer
  let structureLogicButton: int = 491845673 // Button
  let structureLogicCompare: int = -1489728908 // Logic Compare
  let structureLogicDial: int = 554524804 // Dial
  let structureLogicGate: int = 1942143074 // Logic Gate
  let structureLogicHashGen: int = 2077593121 // Logic Hash Generator
  let structureLogicMath: int = 1657691323 // Logic Math
  let structureLogicMathUnary: int = -1160020195 // Math Unary
  let structureLogicMemory: int = -851746783 // Logic Memory
  let structureLogicMinMax: int = 929022276 // Logic Min/Max
  let structureLogicMirror: int = 2096189278 // Logic Mirror
  let structureLogicReader: int = -345383640 // Logic Reader
  let structureLogicReagentReader: int = -124308857 // Reagent Reader
  let structureLogicSelect: int = 1822736084 // Logic Select
  let structureLogicSlotReader: int = -767867194 // Slot Reader
  let structureLogicSwitch: int = 1220484876 // Lever
  let structureLogicSwitch2: int = 321604921 // Switch
  let structureLogicTransmitter: int = -693235651 // Logic Transmitter
  let structureLogicWriter: int = -1326019434 // Logic Writer
  let structureLogicWriterSwitch: int = -1321250424 // Logic Writer Switch
  let structureLowVolumeLiquidPipeCorner: int = -1909140125 // Low Volume Liquid Pipe (Corner)
  let structureLowVolumeLiquidPipeCrossJunction: int = 697935625 // Low Volume Liquid Pipe (Cross Junction)
  let structureLowVolumeLiquidPipeStraight: int = -923441517 // Low Volume Liquid Pipe (Straight)
  let structureLowVolumeLiquidPipeTJunction: int = 1912174058 // Low Volume Liquid Pipe (T Junction)
  let structureLowVolumePipeCorner: int = -1442601681 // Low Volume Pipe (Corner)
  let structureLowVolumePipeCrossJunction: int = -1656624838 // Low Volume Pipe (Cross Junction)
  let structureLowVolumePipeStraight: int = -1002687599 // Low Volume Pipe (Straight)
  let structureLowVolumePipeTJunction: int = -1610883693 // Low Volume Pipe (T Junction)
  let structureManualHatch: int = -1808154199 // Manual Hatch
  let structureMediumConvectionRadiator: int = -1918215845 // Medium Convection Radiator
  let structureMediumConvectionRadiatorLiquid: int = -1169014183 // Medium Convection Radiator Liquid
  let structureMediumHangerDoor: int = -566348148 // Medium Hangar Door
  let structureMediumRadiator: int = -975966237 // Medium Radiator
  let structureMediumRadiatorLiquid: int = -1141760613 // Medium Radiator Liquid
  let structureMotionSensor: int = -1713470563 // Motion Sensor
  let structureNitrolyzer: int = 1898243702 // Nitrolyzer
  let structureOccupancySensor: int = 322782515 // Occupancy Sensor
  let structureOverheadShortCornerLocker: int = -1794932560 // Overhead Corner Locker
  let structureOverheadShortLocker: int = 1468249454 // Overhead Locker
  let structurePassiveLargeRadiatorGas: int = 2066977095 // Medium Convection Radiator
  let structurePassiveLargeRadiatorLiquid: int = 24786172 // Medium Convection Radiator Liquid
  let structurePassiveLiquidDrain: int = 1812364811 // Passive Liquid Drain
  let structurePassiveVent: int = 335498166 // Passive Vent
  let structurePassthroughHeatExchangerGasToGas: int = -1674187440 // CounterFlow Heat Exchanger - Gas + Gas
  let structurePassthroughHeatExchangerGasToLiquid: int = 1928991265 // CounterFlow Heat Exchanger - Gas + Liquid
  let structurePassthroughHeatExchangerLiquidToLiquid: int = -1472829583 // CounterFlow Heat Exchanger - Liquid + Liquid
  let structurePictureFrameThickLandscapeLarge: int = -1434523206 // Picture Frame Thick Landscape Large
  let structurePictureFrameThickLandscapeSmall: int = -2041566697 // Picture Frame Thick Landscape Small
  let structurePictureFrameThickMountLandscapeLarge: int = 950004659 // Picture Frame Thick Landscape Large
  let structurePictureFrameThickMountLandscapeSmall: int = 347154462 // Picture Frame Thick Landscape Small
  let structurePictureFrameThickMountPortraitLarge: int = -1459641358 // Picture Frame Thick Mount Portrait Large
  let structurePictureFrameThickMountPortraitSmall: int = -2066653089 // Picture Frame Thick Mount Portrait Small
  let structurePictureFrameThickPortraitLarge: int = -1686949570 // Picture Frame Thick Portrait Large
  let structurePictureFrameThickPortraitSmall: int = -1218579821 // Picture Frame Thick Portrait Small
  let structurePictureFrameThinLandscapeLarge: int = -1418288625 // Picture Frame Thin Landscape Large
  let structurePictureFrameThinLandscapeSmall: int = -2024250974 // Picture Frame Thin Landscape Small
  let structurePictureFrameThinMountLandscapeLarge: int = -1146760430 // Picture Frame Thin Landscape Large
  let structurePictureFrameThinMountLandscapeSmall: int = -1752493889 // Picture Frame Thin Landscape Small
  let structurePictureFrameThinMountPortraitLarge: int = 1094895077 // Picture Frame Thin Portrait Large
  let structurePictureFrameThinMountPortraitSmall: int = 1835796040 // Picture Frame Thin Portrait Small
  let structurePictureFrameThinPortraitLarge: int = 1212777087 // Picture Frame Thin Portrait Large
  let structurePictureFrameThinPortraitSmall: int = 1684488658 // Picture Frame Thin Portrait Small
  let structurePipeAnalysizer: int = 435685051 // Pipe Analyzer
  let structurePipeCorner: int = -1785673561 // Pipe (Corner)
  let structurePipeCowl: int = 465816159 // Pipe Cowl
  let structurePipeCrossJunction: int = -1405295588 // Pipe (Cross Junction)
  let structurePipeCrossJunction3: int = 2038427184 // Pipe (3-Way Junction)
  let structurePipeCrossJunction4: int = -417629293 // Pipe (4-Way Junction)
  let structurePipeCrossJunction5: int = -1877193979 // Pipe (5-Way Junction)
  let structurePipeCrossJunction6: int = 152378047 // Pipe (6-Way Junction)
  let structurePipeHeater: int = -419758574 // Pipe Heater (Gas)
  let structurePipeInsulatedLiquidCrossJunction: int = -2068497073 // Insulated Liquid Pipe (Cross Junction)
  let structurePipeLabel: int = -999721119 // Pipe Label
  let structurePipeLiquidCorner: int = -1856720921 // Liquid Pipe (Corner)
  let structurePipeLiquidCrossJunction: int = 1848735691 // Liquid Pipe (Cross Junction)
  let structurePipeLiquidCrossJunction3: int = 1628087508 // Liquid Pipe (3-Way Junction)
  let structurePipeLiquidCrossJunction4: int = -9555593 // Liquid Pipe (4-Way Junction)
  let structurePipeLiquidCrossJunction5: int = -2006384159 // Liquid Pipe (5-Way Junction)
  let structurePipeLiquidCrossJunction6: int = 291524699 // Liquid Pipe (6-Way Junction)
  let structurePipeLiquidStraight: int = 667597982 // Liquid Pipe (Straight)
  let structurePipeLiquidTJunction: int = 262616717 // Liquid Pipe (T Junction)
  let structurePipeMeter: int = -1798362329 // Pipe Meter
  let structurePipeOrgan: int = 1305252611 // Pipe Organ
  let structurePipeRadiator: int = 1696603168 // Pipe Convection Radiator
  let structurePipeRadiatorFlat: int = -399883995 // Pipe Radiator
  let structurePipeRadiatorFlatLiquid: int = 2024754523 // Pipe Radiator Liquid
  let structurePipeStraight: int = 73728932 // Pipe (Straight)
  let structurePipeTJunction: int = -913817472 // Pipe (T Junction)
  let structurePlanter: int = -1125641329 // Planter
  let structurePlatformLadderOpen: int = 1559586682 // Ladder Platform
  let structurePlinth: int = 989835703 // Plinth
  let structurePowerConnector: int = -782951720 // Power Connector
  let structurePoweredVent: int = 938836756 // Powered Vent
  let structurePoweredVentLarge: int = -785498334 // Powered Vent Large
  let structurePowerTransmitter: int = -65087121 // Microwave Power Transmitter
  let structurePowerTransmitterOmni: int = -327468845 // Structure Power Transmitter Omni
  let structurePowerTransmitterReceiver: int = 1195820278 // Microwave Power Receiver
  let structurePressurantValve: int = 23052817 // Pressurant Valve
  let structurePressurePlateLarge: int = -2008706143 // Trigger Plate (Large)
  let structurePressurePlateMedium: int = 1269458680 // Trigger Plate (Medium)
  let structurePressurePlateSmall: int = -1536471028 // Trigger Plate (Small)
  let structurePressureRegulator: int = 209854039 // Pressure Regulator
  let structureProximitySensor: int = 568800213 // Proximity Sensor
  let structurePurgeValve: int = -737232128 // Purge Valve
  let structureRailing: int = -1756913871 // Railing Industrial (Type 1)
  let structureRecycler: int = -1633947337 // Recycler
  let structureRefrigeratedVendingMachine: int = -1577831321 // Refrigerated Vending Machine
  let structureReinforcedCompositeWindow: int = 2027713511 // Reinforced Window (Composite)
  let structureReinforcedCompositeWindowSteel: int = -816454272 // Reinforced Window (Composite Steel)
  let structureReinforcedWallPaddedWindow: int = 1939061729 // Reinforced Window (Padded)
  let structureReinforcedWallPaddedWindowThin: int = 158502707 // Reinforced Window (Thin)
  let structureResearchMachine: int = -796627526 // Research Machine
  let structureRocketChuteStorage: int = 1977688565 // <N:EN:StructureRocketChuteStorage>
  let structureRocketEngineTiny: int = 178472613 // Rocket Engine (Tiny)
  let structureRocketPlaceHolderMiner: int = 407081452 // <N:EN:StructureRocketPlaceHolderMiner>
  let structureRover: int = 806513938 // Rover Frame
  let structureSatelliteDish: int = 439026183 // Medium Satellite Dish
  let structureSDBHopper: int = -1875856925 // SDB Hopper
  let structureSDBHopperAdvanced: int = 467225612 // SDB Hopper Advanced
  let structureSDBSilo: int = 1155865682 // SDB Silo
  let structureSecurityPrinter: int = -641491515 // Security Printer
  let structureShelf: int = 1172114950 // Shelf
  let structureShelfMedium: int = 182006674 // Shelf Medium
  let structureShortCornerLocker: int = 1330754486 // Short Corner Locker
  let structureShortLocker: int = -554553467 // Short Locker
  let structureSign1x1: int = 879058460 // Sign 1x1
  let structureSign2x1: int = 908320837 // Sign 2x1
  let structureSingleBed: int = -492611 // Single Bed
  let structureSleeper: int = -1467449329 // Sleeper
  let structureSleeperLeft: int = 1213495833 // Sleeper Left
  let structureSleeperRight: int = -1812330717 // Sleeper Right
  let structureSleeperVertical: int = -1300059018 // Sleeper Vertical
  let structureSleeperVerticalDroid: int = 1382098999 // Droid Sleeper Vertical
  let structureSmallDirectHeatExchangeGastoGas: int = 1310303582 // Small Direct Heat Exchanger - Gas + Gas
  let structureSmallDirectHeatExchangeLiquidtoGas: int = 1825212016 // Small Direct Heat Exchanger - Liquid + Gas
  let structureSmallDirectHeatExchangeLiquidtoLiquid: int = -507770416 // Small Direct Heat Exchanger - Liquid + Liquid
  let structureSmallSatelliteDish: int = -2138748650 // Small Satellite Dish
  let structureSmallTableBacklessDouble: int = -1633000411 // Small (Table Backless Double)
  let structureSmallTableBacklessSingle: int = -1897221677 // Small (Table Backless Single)
  let structureSmallTableDinnerSingle: int = 1260651529 // Small (Table Dinner Single)
  let structureSmallTableRectangleDouble: int = -660451023 // Small (Table Rectangle Double)
  let structureSmallTableRectangleSingle: int = -924678969 // Small (Table Rectangle Single)
  let structureSmallTableThickDouble: int = -19246131 // Small (Table Thick Double)
  let structureSmallTableThickSingle: int = -291862981 // Small Table (Thick Single)
  let structureSolarPanel: int = -2045627372 // Solar Panel
  let structureSolarPanel45: int = -1554349863 // Solar Panel (Angled)
  let structureSolarPanel45Reinforced: int = 930865127 // Solar Panel (Heavy Angled)
  let structureSolarPanelDual: int = -539224550 // Solar Panel (Dual)
  let structureSolarPanelDualReinforced: int = -1545574413 // Solar Panel (Heavy Dual)
  let structureSolarPanelFlat: int = 1968102968 // Solar Panel (Flat)
  let structureSolarPanelFlatReinforced: int = 1697196770 // Solar Panel (Heavy Flat)
  let structureSolarPanelReinforced: int = -934345724 // Solar Panel (Heavy)
  let structureSolidFuelGenerator: int = 813146305 // Generator (Solid Fuel)
  let structureSorter: int = -1009150565 // Sorter
  let structureStacker: int = -2020231820 // Stacker
  let structureStackerReverse: int = 1585641623 // Stacker
  let structureStairs4x2: int = 1405018945 // Stairs
  let structureStairs4x2RailL: int = 155214029 // Stairs with Rail (Left)
  let structureStairs4x2RailR: int = -212902482 // Stairs with Rail (Right)
  let structureStairs4x2Rails: int = -1088008720 // Stairs with Rails
  let structureStairwellBottom: int = 1359864416 // Stairwell Bottom
  let structureStairwellMiddle: int = 1188203019 // Stairwell Middle
  let structureStirlingEngine: int = -260316435 // Stirling Engine
  let structureStorageLocker: int = -793623899 // Locker
  let structureSuitStorage: int = 255034731 // Suit Storage
  let structureTankBig: int = -1606848156 // Large Tank
  let structureTankBigInsulated: int = 1280378227 // Tank Big (Insulated)
  let structureTankConnector: int = -1276379454 // Tank Connector
  let structureTankConnectorLiquid: int = 1331802518 // Liquid Tank Connector
  let structureTankSmall: int = 1013514688 // Small Tank
  let structureTankSmallAir: int = 955744474 // Small Tank (Air)
  let structureTankSmallFuel: int = 2102454415 // Small Tank (Fuel)
  let structureTankSmallInsulated: int = 272136332 // Structure Tank Small Insulated
  let structureToolManufactory: int = -465741100 // Tool Manufactory
  let structureTorpedoRack: int = 1473807953 // Torpedo Rack
  let structureTraderWaypoint: int = 1570931620 // Structure Trader Waypoint
  let structureTransformer: int = -1423212473 // Transformer (Large)
  let structureTransformerMedium: int = -1065725831 // Transformer (Medium)
  let structureTransformerMediumReversed: int = 833912764 // Transformer Reversed (Medium)
  let structureTransformerSmall: int = -890946730 // Transformer (Small)
  let structureTransformerSmallReversed: int = 1054059374 // Transformer Reversed (Small)
  let structureTurbineGenerator: int = 1282191063 // Turbine Generator
  let structureTurboVolumePump: int = 1310794736 // Turbo Volume Pump (Gas)
  let structureUnloader: int = 750118160 // Unloader
  let structureUprightWindTurbine: int = 1622183451 // Upright Wind Turbine
  let structureValve: int = -692036078 // Valve
  let structureVendingMachine: int = -443130773 // Vending Machine
  let structureVolumePump: int = -321403609 // Volume Pump
  let structureWallArch: int = -858143148 // Wall (Arch)
  let structureWallArchArrow: int = 1649708822 // Wall (Arch Arrow)
  let structureWallArchCornerRound: int = 1794588890 // Wall (Arch Corner Round)
  let structureWallArchCornerSquare: int = -1963016580 // Wall (Arch Corner Square)
  let structureWallArchCornerTriangle: int = 1281911841 // Wall (Arch Corner Triangle)
  let structureWallArchPlating: int = 1182510648 // Wall (Arch Plating)
  let structureWallArchTwoTone: int = 782529714 // Wall (Arch Two Tone)
  let structureWallCooler: int = -739292323 // Wall Cooler
  let structureWallFlat: int = 1635864154 // Wall (Flat)
  let structureWallFlatCornerRound: int = 898708250 // Wall (Flat Corner Round)
  let structureWallFlatCornerSquare: int = 298130111 // Wall (Flat Corner Square)
  let structureWallFlatCornerTriangle: int = 2097419366 // Wall (Flat Corner Triangle)
  let structureWallFlatCornerTriangleFlat: int = -1161662836 // Wall (Flat Corner Triangle Flat)
  let structureWallGeometryCorner: int = 1979212240 // Wall (Geometry Corner)
  let structureWallGeometryStreight: int = 1049735537 // Wall (Geometry Straight)
  let structureWallGeometryT: int = 1602758612 // Wall (Geometry T)
  let structureWallGeometryTMirrored: int = -1427845483 // Wall (Geometry T Mirrored)
  let structureWallHeater: int = 24258244 // Wall Heater
  let structureWallIron: int = 1287324802 // Iron Wall (Type 1)
  let structureWallIron02: int = 1485834215 // Iron Wall (Type 2)
  let structureWallIron03: int = 798439281 // Iron Wall (Type 3)
  let structureWallIron04: int = -1309433134 // Iron Wall (Type 4)
  let structureWallLargePanel: int = 1492930217 // Wall (Large Panel)
  let structureWallLargePanelArrow: int = -776581573 // Wall (Large Panel Arrow)
  let structureWallLight: int = -1860064656 // Wall Light
  let structureWallLightBattery: int = -1306415132 // Wall Light (Battery)
  let structureWallPaddedArch: int = 1590330637 // Wall (Padded Arch)
  let structureWallPaddedArchCorner: int = -1126688298 // Wall (Padded Arch Corner)
  let structureWallPaddedArchLightFittingTop: int = 1171987947 // Wall (Padded Arch Light Fitting Top)
  let structureWallPaddedArchLightsFittings: int = -1546743960 // Wall (Padded Arch Lights Fittings)
  let structureWallPaddedCorner: int = -155945899 // Wall (Padded Corner)
  let structureWallPaddedCornerThin: int = 1183203913 // Wall (Padded Corner Thin)
  let structureWallPaddedNoBorder: int = 8846501 // Wall (Padded No Border)
  let structureWallPaddedNoBorderCorner: int = 179694804 // Wall (Padded No Border Corner)
  let structureWallPaddedThinNoBorder: int = -1611559100 // Wall (Padded Thin No Border)
  let structureWallPaddedThinNoBorderCorner: int = 1769527556 // Wall (Padded Thin No Border Corner)
  let structureWallPaddedWindow: int = 2087628940 // Wall (Padded Window)
  let structureWallPaddedWindowThin: int = -37302931 // Wall (Padded Window Thin)
  let structureWallPadding: int = 635995024 // Wall (Padding)
  let structureWallPaddingArchVent: int = -1243329828 // Wall (Padding Arch Vent)
  let structureWallPaddingLightFitting: int = 2024882687 // Wall (Padding Light Fitting)
  let structureWallPaddingThin: int = -1102403554 // Wall (Padding Thin)
  let structureWallPlating: int = 26167457 // Wall (Plating)
  let structureWallSmallPanelsAndHatch: int = 619828719 // Wall (Small Panels And Hatch)
  let structureWallSmallPanelsArrow: int = -639306697 // Wall (Small Panels Arrow)
  let structureWallSmallPanelsMonoChrome: int = 386820253 // Wall (Small Panels Mono Chrome)
  let structureWallSmallPanelsOpen: int = -1407480603 // Wall (Small Panels Open)
  let structureWallSmallPanelsTwoTone: int = 1709994581 // Wall (Small Panels Two Tone)
  let structureWallVent: int = -1177469307 // Wall Vent
  let structureWaterBottleFiller: int = -1178961954 // Water Bottle Filler
  let structureWaterBottleFillerBottom: int = 1433754995 // Water Bottle Filler Bottom
  let structureWaterBottleFillerPowered: int = -756587791 // Waterbottle Filler
  let structureWaterBottleFillerPoweredBottom: int = 1986658780 // Waterbottle Filler
  let structureWaterDigitalValve: int = -517628750 // Liquid Digital Valve
  let structureWaterPipeMeter: int = 433184168 // Liquid Pipe Meter
  let structureWaterWallCooler: int = -1369060582 // Liquid Wall Cooler
  let structureWeatherStation: int = 1997212478 // Weather Station
  let structureWindowShutter: int = 2056377335 // Window Shutter
  let structureWindTurbine: int = -2082355173 // Wind Turbine
  let toolPrinterMod: int = 1700018136 // Tool Printer Mod
  let toyLuna: int = 94730034 // Toy Luna
  let uniformCommander: int = -2083426457 // Uniform Commander
  let uniformMarine: int = -48342840 // Marine Uniform
  let uniformOrangeJumpSuit: int = 810053150 // Jump Suit (Orange)
  let weaponEnergy: int = 789494694 // Weapon Energy
  let weaponPistolEnergy: int = -385323479 // Energy Pistol
  let weaponRifleEnergy: int = 1154745374 // Energy Rifle
  let weaponTorpedo: int = -1102977898 // Torpedo
}
// --- END GENERATED ---
`

let exampleCode = `// Furnace heater: keeps a furnace below a temperature limit.
let furnace = device("d0")
let sensor = device("d1")

let limit = 500.

while true {
  let temp = l(sensor, "Temperature")
  s(furnace, "On", temp < limit)
  yield()
}
`

let rescriptConfig = (projectName: string) =>
  `{
  "name": "${projectName}",
  "sources": [{"dir": "src", "subdirs": true}],
  "package-specs": [{"module": "esmodule", "in-source": true}],
  "suffix": ".res.mjs",
  "compiler-flags": ["-open IC10"]
}
`

let packageJson = (projectName: string) =>
  `{
  "name": "${projectName}",
  "version": "1.0.0",
  "private": true,
  "description": "Stationeers IC10 scripts written in ReScript",
  "scripts": {
    "typecheck": "rescript",
    "compile": "ric10 src/Example.res"
  },
  "devDependencies": {
    "rescript": "^12.1.0",
    "rescript-ic10-compiler": "^0.2.0"
  }
}
`

let readme = (projectName: string) =>
  `# ${projectName}

Stationeers IC10 scripts written in ReScript and compiled with ric10.

## Workflow

    npm install
    npm run typecheck          # the real ReScript compiler checks your program
    npx ric10 src/Example.res  # writes src/Example.ic10

Paste the .ic10 file into an IC housing in game.

## Files

- src/IC10.res: bindings for IC10 instructions (devices, batch ops, stack, yield)
- src/Example.res: your script

## Cheatsheet

    let sensor = device("d0")                  // pins d0..d5, db
    let t = l(sensor, "Temperature")           // read (float)
    s(d1, "On", t > 300.)                      // write int/float/bool
    let tanks = hash("StructureTankSmall")
    let avg = lb(tanks, "Pressure", Average)   // batch read
    yield()                                    // wait one tick

Language: let, refs, if/switch/blocks as expressions, while, for, functions with
parameters, variants with payloads, pattern matching. Math via Math.* .

## Resources

- https://stationeers-wiki.com/IC10
- https://rescript-lang.org
`

let gitignore = `node_modules/
lib/
*.res.mjs
`
