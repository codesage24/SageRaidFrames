-- Defaults
DEFAULTS = {
    cellWidth = 80,
    cellHeight = 40,
    spacing = 4,
    gridCols = 5,
    posX = 200,
    posY = 200,
    orientation = "HORIZONTAL", -- or "VERTICAL"
}

-- Maximum number of units to display
MAX_UNITS = 25

-- Power type color constants
POWER_COLORS = {
    [0] = {r = 0.0, g = 0.0, b = 1.0}, -- Mana (blue)
    [1] = {r = 1.0, g = 0.0, b = 0.0}, -- Rage (red)
    [2] = {r = 1.0, g = 1.0, b = 0.0}, -- Focus (yellow)
    [3] = {r = 1.0, g = 1.0, b = 0.0}, -- Energy (yellow)
    [4] = {r = 0.0, g = 1.0, b = 1.0}, -- Happiness (cyan)
    [6] = {r = 1.0, g = 0.5, b = 1.0}, -- Runic Power (magenta)
}
