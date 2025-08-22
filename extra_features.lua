
-- SYSMSG
local function GetGuildRankForPlayer(name)
    if not IsInGuild() then return nil end
    
    GuildRoster() -- Update guild data
    local numMembers = GetNumGuildMembers(true)
    
    for i = 1, numMembers do
        local memberName, rank = GetGuildRosterInfo(i)
        local shortName = memberName
        local dashPos = string.find(memberName or "", "-")
        if dashPos then
            shortName = string.sub(memberName, 1, dashPos - 1)
        end
        
        if shortName == name then
            return rank
        end
    end
    return nil
end


local frame = CreateFrame("Frame", "FakeSysFrame")
frame:RegisterEvent("CHAT_MSG_ADDON")


frame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
        if arg1 == "FakeSys" then
            -- Display the fake system message
            DEFAULT_CHAT_FRAME:AddMessage(arg2, 1.0, 1.0, 0.0)
        end
    end
end)

-- Slash command handler
local function FakeSysHandler(msg)
    -- Check if player is an officer
    local playerName = UnitName("player")
    local rank = GetGuildRankForPlayer(playerName)
    
    if not rank or (rank ~= "Officer") then
        return
    end
    
    if msg and msg ~= "" then
        SendAddonMessage("FakeSys", msg, "GUILD")
    end
end

-- Register the slash command
SLASH_FAKESYS1 = "/fakesys"
SlashCmdList["FAKESYS"] = FakeSysHandler


-- PARSE ID
SLASH_PARSEID1 = "/parseid"

SlashCmdList["PARSEID"] = function(msg)

  local _, _, itemID = string.find(msg, "Hitem:(%d+)")
  
  if itemID then
    DEFAULT_CHAT_FRAME:AddMessage("Item ID is: " .. itemID)
  else
    DEFAULT_CHAT_FRAME:AddMessage(
      "No item ID found. Make sure to shift-click an actual item link.\nReceived: " .. (msg or "nil")
    )
  end
end




-- ROLL COLORS
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_SYSTEM")

-- Function to get guild rank
local function GetGuildRankForPlayer(name)
    if not IsInGuild() then return nil end
    
    GuildRoster() -- Update guild data
    local numMembers = GetNumGuildMembers(true)
    
    for i = 1, numMembers do
        local memberName, rank = GetGuildRosterInfo(i)
        -- Remove server name if present
        local shortName = memberName
        local dashPos = string.find(memberName or "", "-")
        if dashPos then
            shortName = string.sub(memberName, 1, dashPos - 1)
        end
        
        if shortName == name then
            return rank
        end
    end
    return nil
end

-- Store the original function
local originalChatFrame_OnEvent = ChatFrame_OnEvent

-- Replace the event handler to filter out the original roll message
ChatFrame_OnEvent = function(event)
    if event == "CHAT_MSG_SYSTEM" then
        local message = arg1
        if message then
            local _, _, name, roll, range = string.find(message, "^([^%s]+) rolls (%d+) %(1%-(%d+)%)$")
            
            if name and roll then
                local rank = GetGuildRankForPlayer(name)
                
                -- Create the modified message - always color the roll number green
                local modifiedMessage
                
                if rank and rank ~= "" then
                    -- Include rank for guild members
                    modifiedMessage = name .. " <" .. rank .. "> rolls |cFF00FF00" .. roll .. "|r (1-" .. range .. ")"
                else
                    -- No rank, but still color the number
                    modifiedMessage = name .. " rolls |cFF00FF00" .. roll .. "|r (1-" .. range .. ")"
                end
                
                -- Display the message with proper yellow system color
                DEFAULT_CHAT_FRAME:AddMessage(modifiedMessage, 1, 1, 0)
                
                -- Skip original message
                return
            end
        end
    end
    
    -- Call original handler for all other messages
    originalChatFrame_OnEvent(event)
end



-- Turn loot sounds on/off
if sepgp_sound == nil then
    sepgp_sound = 1 
end

-- Slash command handler function
local function HandleLootSoundCommand(msg)
    local command
    if msg then
        command = string.lower(msg)
    else
        command = ""
    end
    
    if command == "on" then
        sepgp_sound = 1
        DEFAULT_CHAT_FRAME:AddMessage("Loot sounds |cFF00FF00enabled|r")
    elseif command == "off" then
        sepgp_sound = 0
        DEFAULT_CHAT_FRAME:AddMessage("Loot sounds |cFFFF0000disabled|r (" .. UnitName("player") .. ", you're boring)")
    end
end

-- Register the slash commands
SLASH_LOOTSOUND1 = "/lootsound"
SlashCmdList["LOOTSOUND"] = HandleLootSoundCommand