local settings = {}

-- Add a saved dock option. Queue the change so the current page can be rebuilt
-- after the checkbox hook finishes.
local function option(root, width, y, label, value, queue, change)
    local check = ui.Check.new(root)
    check:SetPos(8, y)
    check:SetSize(width - 16, 28)
    check.stylesheetID = id.StyleSheet.CHECKBOX_DEFAULT
    check.label = label
    check.value = value == true
    check.alignment = ui.CheckAlignMode.LEFT
    check.buttonSize = 18
    check:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
        local checked = check.value
        queue(function() change(checked) end)
    end)
end

-- Linza can be shown or hidden manually even when her quest status is known.
-- Akrisae follows his quest status and has no manual setting.
function settings.build(root, width, run, queue, save)
    option(root, width, 35, "Show Linza", run.showLinza, queue,
        function(checked)
            run.manualLinza = true
            run.showLinza = checked
            save()
        end)
    option(root, width, 70, "Show Linza KC", run.showLinzaKC, queue,
        function(checked)
            run.showLinzaKC = checked
            save()
        end)
    option(root, width, 105, "Show combat styles", run.showCombatStyles, queue,
        function(checked)
            run.showCombatStyles = checked
            save()
        end)

    local reset = ui.Button.new(root)
    reset:SetPos(8, 147)
    reset:SetSize(width - 16, 26)
    reset.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
    reset.label = "Reset Linza KC"
    local confirming = false
    reset:Subscribe(ui.Hook.ONBUTTONPRESSED, function()
        if not confirming then
            -- Arm the reset on the first click; leaving settings discards it.
            confirming = true
            reset.label = "Confirm Reset?"
            return
        end
        queue(function()
            run.linzaKills = 0
            -- Keep linzaCounted while her kill flag is active to avoid recounting it.
            save()
        end)
    end)

    local count = ui.Text.new(root)
    count:SetPos(8, 180)
    count:SetSize(width - 16, 20)
    count.content = "Current Linza KC: " .. run.linzaKills
    count.font = id.Font.MUSEO_SANS_15PT_REGULAR
    count.clickthrough = true
end

return settings
