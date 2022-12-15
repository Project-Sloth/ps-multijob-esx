local ESX = exports['es_extended']:getSharedObject()

local function GetJobs()
    local p = promise.new()
    ESX.TriggerServerCallback('ps-multijob:getJobs', function(result)
        p:resolve(result)
    end)
    return Citizen.Await(p)
end

local function OpenUI()
    local job = ESX.GetPlayerData().job
    SetNuiFocus(true,true)
    SendNUIMessage({
        action = 'sendjobs',
        activeJob = job.name,
        onDuty = true,
        jobs = GetJobs(),
        side = Config.Side,
    })
end

RegisterNUICallback('selectjob', function(data, cb)
    TriggerServerEvent("ps-multijob:changeJob", data["name"], data["grade"])
    local onDuty = false
        -- Need to do ESX job 
    cb({onDuty = onDuty})
end)

RegisterNUICallback('closemenu', function(data, cb)
    cb({})
    SetNuiFocus(false,false)
end)

RegisterNUICallback('removejob', function(data, cb)
    TriggerServerEvent("ps-multijob:removeJob", data["name"], data["grade"])
    local jobs = GetJobs()
    jobs[data["name"]] = nil
    cb(jobs)
end)

RegisterNUICallback('toggleduty', function(data, cb)
    cb({})
        -- Need to do ESX job onduty
end)

RegisterNetEvent('esx:setJob', function(newJob)
    SendNUIMessage({
        action = 'updatejob',
        name = newJob["name"],
        label = newJob["label"],
        onDuty = true,
        gradeLabel = newJob["grade_label"],
        grade = newJob["grade"],
        payment = newJob["grade_salary"],
    })

end)

RegisterCommand("jobmenu", OpenUI)

RegisterKeyMapping('jobmenu', "Show Job Management", "keyboard", "J")

TriggerEvent('chat:removeSuggestion', '/jobmenu')
