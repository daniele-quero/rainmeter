function Initialize()
    _G.dayProgressPercent = 0
    _G.lastComputedKey = ""
    updateDayProgress()
end

function updateDayProgress()
    local now = os.date("*t")
    local todayKey = string.format("%04d-%02d-%02d", now.year, now.month, now.day)
    local nextMonth = now.month + 1
    local nextYear = now.year

    if nextMonth > 12 then
        nextMonth = 1
        nextYear = nextYear + 1
    end

    local totalDays = os.date("*t", os.time({year = nextYear, month = nextMonth, day = 0})).day
    _G.dayProgressPercent = (now.day / totalDays) * 100
    _G.lastComputedKey = todayKey
end

function Update()
    local now = os.date("*t")
    local todayKey = string.format("%04d-%02d-%02d", now.year, now.month, now.day)

    if _G.lastComputedKey ~= todayKey then
        updateDayProgress()
    end

    return string.format("%.0f", _G.dayProgressPercent)
end
