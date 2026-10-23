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
