
local PedCreate, startPedScreen = {}, false

local playerPed = cache.ped
lib.onCache('ped', function(ped)
	playerPed = ped
end)

local function createPed(model, locationx, locationy, locationz)
    RequestModel(model)
    return CreatePed(26, model, locationx, locationy, locationz, 0, false, false)
end

local function PedScreenDelete()
    for _,v in pairs(PedCreate) do 
        DeleteEntity(v)
    end

    PedCreate = {} 
    startPedScreen = false 
end

local function RenderCam()
    local totalTime = 1000 
    local elapsed = 0
    local startingPitch = GetGameplayCamRelativePitch() 
    local targetPitch = 0.0
    local rate = 1.0
    local pitchThreshold = 30.00  
    
    if math.abs(startingPitch + 7.0) < pitchThreshold then
        return
    end

    if LocalPlayer.state.invOpen then 
        if math.abs(startingPitch - targetPitch) > 0.01 then
            CreateThread(function()
                while elapsed < totalTime and startPedScreen do
                    Wait(0)
                    elapsed = elapsed + 10 
                    local progress = elapsed / totalTime
                    local currentPitch = (1.0 - progress) * startingPitch + progress * targetPitch
                    SetGameplayCamRelativePitch(currentPitch, rate)
                end
            end)
        end
    end
end

local function createAndConfigurePed(playerPed, animation)
    local clonedPed = createPed(GetEntityModel(playerPed), nil, nil, nil)

    SetEntityCollision(clonedPed, false, true)
    SetEntityInvincible(clonedPed, true)
    NetworkSetEntityInvisibleToNetwork(clonedPed, false)
    ClonePedToTarget(playerPed, clonedPed)
    SetEntityCanBeDamaged(clonedPed, false)
    SetBlockingOfNonTemporaryEvents(clonedPed, true)
    SetPedAsNoLongerNeeded(clonedPed)
    SetForcePedFootstepsTracks(false)

    if animation.dict and animation.anim then
        lib.requestAnimDict(animation.dict)
        TaskPlayAnim(clonedPed, animation.dict, animation.anim, 8.0, 1.0, -1, 1, 0, false, false, false)
    end

    return clonedPed
end

local function updatePedPosition(clonedPed, positionBuffer, camRot, headingOffset, scaleWidth, upTempOffset)
    local averagedTarget = vector3(0, 0, 0)
    for _, position in ipairs(positionBuffer) do
        averagedTarget = averagedTarget + position
    end
    averagedTarget = averagedTarget / #positionBuffer

    DisableIdleCamera(true)
    SetBlockingOfNonTemporaryEvents(clonedPed, true)
    SetEntityCollision(clonedPed, false, false)
    SetEntityCoords(clonedPed, averagedTarget.x, averagedTarget.y, averagedTarget.z, false, false, false, true)
    SetEntityHeading(clonedPed, camRot.z + 180.0 + headingOffset)
    SetEntityRotation(clonedPed, 0, 0, camRot.z + 180.0 + headingOffset, false, false)
    FreezeEntityPosition(clonedPed, true)
    SetPedCanRagdoll(clonedPed, false)
    SetPedCanBeTargetted(clonedPed, false)
    SetPedCanBeTargettedByPlayer(clonedPed, PlayerId(), false)
    SetPedCanEvasiveDive(clonedPed, false)
    SetPedCanRagdollFromPlayerImpact(clonedPed, false)
    SetPedConfigFlag(clonedPed, 209, true) 
    SetPedConfigFlag(clonedPed, 208, true) 
    SetPedConfigFlag(clonedPed, 104, true) 
    SetPedConfigFlag(clonedPed, 429, true) 
    SetPedConfigFlag(clonedPed, 312, true) 
    SetPedConfigFlag(clonedPed, 330, true) 
    SetEntityInvincible(clonedPed, true)
    local forward, right, up, _ = GetEntityMatrix(clonedPed)
    right = right * scaleWidth 
    SetEntityMatrix(clonedPed, forward, right, up + vector3(0, 0, upTempOffset), averagedTarget)
end

local function PedScreenCreate(animation, control, type, data)
    if not control then 
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if GetEntitySpeed(vehicle) * 3.5 > 80 then
            return
        end
    end

    SetGameplayCamRelativePitch(1.0, 1.0)
    PedScreenDelete()
    RenderCam()

    local clonedPed = createAndConfigurePed(playerPed, animation)
    table.insert(PedCreate, clonedPed)

    startPedScreen = true 
    CreateThread(function()
        local positionBuffer = {}
        local bufferSize, scaleWidth, upTempOffset

        while startPedScreen do 
            local world, normal, depth

            if type == "animation" then 
                depth, bufferSize, scaleWidth, upTempOffset = data.depth, data.bufferSize, data.scaleWidth, data.upTempOffset
                world, normal = GetWorldCoordFromScreenCoord(0.70035417461395, 0.2587036895752)
            else
                depth, bufferSize, scaleWidth, upTempOffset = 1.4, 2, 0.58, -0.48
                world, normal = GetWorldCoordFromScreenCoord(0.51, 0.43)
            end

            local target = world + normal * depth
            local camRot = GetGameplayCamRot(2)
 
    
            table.insert(positionBuffer, target)
            if #positionBuffer > bufferSize then
                table.remove(positionBuffer, 1)
            end

            updatePedPosition(clonedPed, positionBuffer, camRot, 0.0, scaleWidth, upTempOffset)
            if control then 
                DisableAllControlActions(0)
            end

            Wait(0)
        end
    end)
end

local function ResetPedScreen()
    CreateThread(function()
        PedScreenCreate({
            dict = "anim@amb@casino@valet_scenario@pose_d@", 
            anim = "base_a_m_y_vinewood_01"
        })
    end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then 
        for _,v in pairs(PedCreate) do 
            DeleteEntity(v)
        end
    end
end)

exports('ResetPedScreen', ResetPedScreen)
exports('PedScreenDelete', PedScreenDelete)
exports('PedScreenCreate', PedScreenCreate)

AddStateBagChangeHandler('invOpen', nil, function(_, key, value)
    if key == "invOpen" then
        if value then
            PedScreenCreate({
                dict = "anim@amb@casino@valet_scenario@pose_d@", 
                anim = "base_a_m_y_vinewood_01"
            })
        else
            PedScreenDelete()
        end
    end
end)
