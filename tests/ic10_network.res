let avgTemp = lbn("Furnace", "MainFurnace", "Temperature", "Average")

let maxPressure = lbn("GasSensor", "Reactor", "Pressure", "Maximum")

sbn("LEDDisplay", "StatusDisplay", "Setting", 100)

sbn("Heater", "MainHeater", "On", 0)
