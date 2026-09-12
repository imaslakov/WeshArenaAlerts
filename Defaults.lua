local _, WAA = ...

WAA.Defaults = {
    general = {
        enabled = true,
        showDebugMessages = false,
    },
    modules = {
        drinking = {
            enabled = true,
            playSound = true,
            textSize = 48,
            duration = 3.0,
        },
        scatter = {
            enabled = true,
            flashEnabled = true,
            opacity = 0.55,
            duration = 0.45,
        },
        wyvernSting = {
            enabled = true,
            flashEnabled = true,
            opacity = 0.55,
            duration = 0.45,
        },
        innerFire = {
            enabled = true,
            threshold = 5,
            iconSize = 72,
            showStackCount = true,
        },
        classIcon = {
            enabled = true,
            iconSize = 28,
            offsetX = 0,
            offsetY = 4,
            showBorder = true,
        },
        shieldAbsorb = {
            enabled = true,
            iconSize = 72,
            textSize = 28,
            numberFormat = "EXACT",
            displayMode = "ICON_NUMBER",
        },
        enemyOverpower = {
            enabled = true,
            iconSize = 72,
            showCountdown = true,
            playSound = true,
        },
        executeRange = {
            enabled = true,
            textSize = 36,
        },
    },
    positions = {
        drinking = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 170,
        },
        innerFire = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = -150,
            y = 30,
        },
        shieldAbsorb = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 30,
        },
        enemyOverpower = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 150,
            y = 30,
        },
        executeRange = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = -90,
        },
    },
}
