local ESX = exports['es_extended']:getSharedObject()

local function GetJobs(identifier)
    local p = promise.new()
    MySQL.Async.fetchAll("SELECT jobdata FROM multijobs WHERE identifier = @identifier",{
        ["@identifier"] = identifier
    }, function(jobs)
        if jobs[1] and jobs ~= "[]" then
            jobs = json.decode(jobs[1].jobdata)
        else
            local Player = ESX.GetPlayerFromIdentifier(identifier)
            local temp = {}
            print(Player)
            if not Config.IgnoredJobs[Player.job.name] then
                temp[Player.job.name] = Player.job.grade
                MySQL.insert('INSERT INTO multijobs (identifier, jobdata) VALUES (:identifier, :jobdata) ON DUPLICATE KEY UPDATE jobdata = :jobdata', {
                    identifier = identifier,
                    jobdata = json.encode(temp),
                })
            end
            jobs = temp
        end
        p:resolve(jobs)
    end)
    return Citizen.Await(p)
end
    
local function AddJob(identifier, job, grade)
    local jobs = GetJobs(identifier)
    for ignored in pairs(Config.IgnoredJobs) do
        if jobs[ignored] then
            jobs[ignored] = nil
        end
    end

    jobs[job] = grade
    MySQL.insert('INSERT INTO multijobs (identifier, jobdata) VALUES (:identifier, :jobdata) ON DUPLICATE KEY UPDATE jobdata = :jobdata', {
        identifier = identifier,
        jobdata = json.encode(jobs),
    })
end

local function RemoveJob(identifier, job, grade)
    local jobs = GetJobs(identifier)
    jobs[job] = nil
    local Player = ESX.GetPlayerFromIdentifier(identifier)
    if Player.job == job then
        for k,v in pairs(jobs) do
            Player.setJob(k,v)
            break
        end
    end
    MySQL.insert('INSERT INTO multijobs (identifier, jobdata) VALUES (:identifier, :jobdata) ON DUPLICATE KEY UPDATE jobdata = :jobdata', {
        identifier = identifier,
        jobdata = json.encode(jobs),
    })
end


ESX.RegisterCommand('removejob', 'admin', function(xPlayer, args, showError)

    if not ESX.DoesJobExist(args.job, args.grade) then
        showError("Invalid Job")
        return
    end
    if args.job and args.grade then
        RemoveJob(xPlayer.identifier, args.job, args.grade)
    end


end, false, {help = 'remove job from multijob (admin)', validate = true, arguments = {
	{name = 'playerId', help = 'player id', type = 'player'},
	{name = 'job', help = 'job', type = 'string'},
	{name = 'grade', help = 'grade', type = 'number'}
}})

ESX.RegisterCommand('addjob', 'admin', function(xPlayer, args, showError)

    if not ESX.DoesJobExist(args.job, args.grade) then
        showError("Invalid Job")
        return
    end
    if args.job and args.grade then
        AddJob(xPlayer.identifier, args.job, args.grade)
    end


end, false, {help = 'add job to multijob (admin)', validate = true, arguments = {
	{name = 'playerId', help = 'player id', type = 'player'},
	{name = 'job', help = 'job', type = 'string'},
	{name = 'grade', help = 'grade', type = 'number'}
}})

ESX.RegisterServerCallback("ps-multijob:getJobs",function(source, cb)
    local Player = ESX.GetPlayerFromId(source)
    local jobs = GetJobs(Player.identifier)
    local multijobs = {}
    local whitelistedjobs = {}
    local civjobs = {}
    local active = {}
    local getjobs = {}
    local JobData = ESX.GetJobs()
    local Players = ESX.GetPlayers()
    for i = 1, #Players, 1 do
        local xPlayer = ESX.GetPlayerFromId(Players[i])
        active[xPlayer.job.name] = 0
        if active[xPlayer.job.name] then
            active[xPlayer.job.name] = active[xPlayer.job.name] + 1
        end
    end
    for job, grade in pairs(jobs) do
        local online = active[job]
        if online == nil then
            online = 0
        end
        getjobs = {
            name = job,
            grade = grade,
            description = Config.Descriptions[job],
            icon = Config.FontAwesomeIcons[job],
            label = JobData[job].label,
            grade_label = JobData[job].grade_label,
            salary = JobData[job].grade_salary,
            active = online,
        }
        if Config.WhitelistJobs[job] then
            whitelistedjobs[#whitelistedjobs+1] = getjobs
        else
            civjobs[#civjobs+1] = getjobs
        end
        multijobs = {
            whitelist = whitelistedjobs,
            civilian = civjobs,
        }
    end
    cb(multijobs)
end)

RegisterNetEvent("ps-multijob:changeJob",function(cjob, cgrade)
    local source = source
    local Player = ESX.GetPlayerFromId(source)

    if cjob == "unemployed" and cgrade == 0 then
        Player.setJob(cjob, cgrade)
        return
    end

    local jobs = GetJobs(Player.identifier)
    for job, grade in pairs(jobs) do
        if cjob == job and cgrade == grade then
            Player.setJob(job, grade)
        end
    end
end)

RegisterNetEvent("ps-multijob:removeJob",function(job, grade)
    local source = source
    local Player = ESX.GetPlayerFromId(source)
    RemoveJob(Player.identifier, job, grade)
end)

RegisterNetEvent('esx:setJob', function(source, newJob)
    local source = source
    local Player = ESX.GetPlayerFromId(source)
    local jobs = GetJobs(Player.identifier)
    local amount = 0
    local setjob = newJob
    for k,v in pairs(jobs) do
        amount = amount + 1
    end
    if amount < Config.MaxJobs and not Config.IgnoredJobs[setjob.name] then
        if not jobs[setjob.name] then
            AddJob(Player.identifier, setjob.name, setjob.grade.level)
        end
    end
end)