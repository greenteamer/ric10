let avgTemp = lbn(hash("Furnace"), hash("MainFurnace"), "Temperature", "Average")

let maxPressure = lbn(hash("GasSensor"), hash("Reactor"), "Pressure", "Maximum")

sbn("LEDDisplay", "StatusDisplay", "Setting", 100)

sbn("Heater", "MainHeater", "On", 0)
