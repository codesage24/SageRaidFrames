-- Function for Creating a Slider with an associated Edit Box
function Utils_CreateSliderWithBox(label, parent, predecessor, minValue, maxValue, getFunc, setFunc)
    -- MUST HAVE A NAME WHEN USING OptionsSliderTemplate
    local slider = CreateFrame("Slider", "SRF_Slider_"..label:gsub("%s+", "_"), parent, "OptionsSliderTemplate")

    slider:SetPoint("TOPLEFT", predecessor, "BOTTOMLEFT", 0, -40)
    slider:SetWidth(200)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)

    local value = tonumber(getFunc()) or minValue
    slider:SetValue(value)

    local name = slider:GetName()
    _G[name.."Low"]:SetText(tostring(minValue))
    _G[name.."High"]:SetText(tostring(maxValue))
    _G[name.."Text"]:SetText(label)

    local box = CreateFrame("EditBox", "SRF_Box_"..label:gsub("%s+", "_"), parent, "InputBoxTemplate")
    box:SetPoint("LEFT", slider, "RIGHT", 20, 0)
    box:SetAutoFocus(false)
    box:SetSize(50, 20)
    box:SetNumeric(true)
    box:SetText(tostring(value))

    slider:SetScript("OnValueChanged", function(self, newVal)
        newVal = math.floor(tonumber(newVal) or value)
        box:SetText(tostring(newVal))
        setFunc(newVal)
    end)

    box:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then
            v = math.max(minValue, math.min(maxValue, v))
            slider:SetValue(v)
            setFunc(v)
        else
            box:SetText(tostring(slider:GetValue()))
        end
        self:ClearFocus()
    end)

    return slider, box
end
