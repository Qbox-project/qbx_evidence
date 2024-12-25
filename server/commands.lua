local function dnaHash(s)
    return string.gsub(s, '.', function(c)
        return string.format('%02x', string.byte(c))
    end)
end

local function IsLeoAndOnDuty(player, minGrade)
    local job = player.PlayerData.job
    if job and job.type == 'leo' and job.onduty then
        return job.grade.level >= (minGrade or 0)
    end
end

local function checkLeoAndOnDuty(player, minGrade)
    if IsLeoAndOnDuty(player, minGrade) then return true end
    exports.qbx_core:Notify(player.PlayerData.source, locale('error.on_duty_police_only'), 'error')
end

lib.addCommand('takedna', {
    help = locale('commands.takedna'),
    params = {{
        name = 'id',
        type = 'playerId',
        help = locale('info.player_id')
    }},
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    local otherPlayer = exports.qbx_core:GetPlayer(args.id)

    if not checkLeoAndOnDuty(player) then return end
    if not player.Functions.RemoveItem('empty_evidence_bag', 1) then
        return exports.qbx_core:Notify(source, locale('error.have_evidence_bag'), 'error')
    end

    local info = {
        label = locale('info.dna_sample'),
        type = 'dna',
        dnalabel = dnaHash(otherPlayer.PlayerData.citizenid),
        description = dnaHash(otherPlayer.PlayerData.citizenid)
    }
    if not player.Functions.AddItem('filled_evidence_bag', 1, false, info) then return end
end)