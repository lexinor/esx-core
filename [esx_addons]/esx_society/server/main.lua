local Jobs = {}
local Factions = {}
local RegisteredSocieties = {}

function GetSociety(name)
	for i=1, #RegisteredSocieties, 1 do
		if RegisteredSocieties[i].name == name then
			return RegisteredSocieties[i]
		end
	end
end

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		local result_job = MySQL.query.await('SELECT * FROM jobs')
		local result_faction = MySQL.query.await('SELECT * FROM factions')

		for i = 1, #result_job do
			Jobs[result_job[i].name] = result_job[i]
			Jobs[result_job[i].name].grades = {}
		end

		for i = 1, #result_faction do
			Factions[result_faction[i].name] = result_faction[i]
			Factions[result_faction[i].name].grades = {}
		end

		local result2_job = MySQL.query.await('SELECT * FROM job_grades')
		local result2_faction = MySQL.query.await('SELECT * FROM faction_grades')

		for i = 1, #result2_job do
			Jobs[result2_job[i].job_name].grades[tostring(result2_job[i].grade)] = result2_job[i]
		end

		for i = 1, #result2_faction do
			Factions[result2_faction[i].faction_name].grades[tostring(result2_faction[i].grade)] = result2_faction[i]
		end
	end
end)

AddEventHandler('esx_society:registerSociety', function(name, label, account, datastore, inventory, data)
	local found = false

	local society = {
		name = name,
		label = label,
		account = account,
		datastore = datastore,
		inventory = inventory,
		data = data
	}

	for i=1, #RegisteredSocieties, 1 do
		if RegisteredSocieties[i].name == name then
			found, RegisteredSocieties[i] = true, society
			break
		end
	end

	if not found then
		table.insert(RegisteredSocieties, society)
	end
end)

AddEventHandler('esx_society:getSocieties', function(cb)
	cb(RegisteredSocieties)
end)

AddEventHandler('esx_society:getSociety', function(name, cb)
	cb(GetSociety(name))
end)

RegisterServerEvent('esx_society:checkSocietyBalance')
AddEventHandler('esx_society:checkSocietyBalance', function(society)
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(society)

	if xPlayer.job.name ~= society.name then
		print(('esx_society: %s attempted to call checkSocietyBalance!'):format(xPlayer.identifier))
		return
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
		TriggerClientEvent("esx:showNotification", xPlayer.source, TranslateCap('check_balance', ESX.Math.GroupDigits(account.money)))
	end)
end)

RegisterServerEvent('esx_society:withdrawMoney')
AddEventHandler('esx_society:withdrawMoney', function(societyName, amount)
	local source = source
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to withdraw from non-existing society - ^5%s^7!'):format(source, societyName))
		return
	end
	local xPlayer = ESX.GetPlayerFromId(source)
	amount = ESX.Math.Round(tonumber(amount))
	if (xPlayer.job.name == society.name) or (xPlayer.faction.name == society.name) then
		TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
			if amount > 0 and account.money >= amount then
				account.removeMoney(amount)
				xPlayer.addMoney(amount, "Society Withdraw")
				xPlayer.showNotification(TranslateCap('have_withdrawn', ESX.Math.GroupDigits(amount)))
			else
				xPlayer.showNotification(TranslateCap('invalid_amount'))
			end
		end)
	else
		print(('[^3WARNING^7] Player ^5%s^7 attempted to withdraw from society - ^5%s^7!'):format(source, society.name))
	end
end)

RegisterServerEvent('esx_society:depositMoney')
AddEventHandler('esx_society:depositMoney', function(societyName, amount)
	local source = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to deposit to non-existing society - ^5%s^7!'):format(source, societyName))
		return
	end
	amount = ESX.Math.Round(tonumber(amount))

	if (xPlayer.job.name == society.name) or (xPlayer.faction.name == society.name) then
		if amount > 0 and xPlayer.getMoney() >= amount then
			TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
				xPlayer.removeMoney(amount, "Society Deposit")
				xPlayer.showNotification(TranslateCap('have_deposited', ESX.Math.GroupDigits(amount)))
				account.addMoney(amount)
			end)
		else
			xPlayer.showNotification(TranslateCap('invalid_amount'))
		end
	else
		print(('[^3WARNING^7] Player ^5%s^7 attempted to deposit to society - ^5%s^7!'):format(source, society.name))
	end
end)

RegisterServerEvent('esx_society:washMoney')
AddEventHandler('esx_society:washMoney', function(society, amount)
	local source = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local account = xPlayer.getAccount('black_money')
	amount = ESX.Math.Round(tonumber(amount))

	if (xPlayer.job.name == society.name) or (xPlayer.faction.name == society.name) then
		if amount and amount > 0 and account.money >= amount then
			xPlayer.removeAccountMoney('black_money', amount, "Washing")

			MySQL.insert('INSERT INTO society_moneywash (identifier, society, amount) VALUES (?, ?, ?)', {xPlayer.identifier, society, amount},
			function(rowsChanged)
				xPlayer.showNotification(TranslateCap('you_have', ESX.Math.GroupDigits(amount)))
			end)
		else
			xPlayer.showNotification(TranslateCap('invalid_amount'))
		end
	else
		print(('[^3WARNING^7] Player ^5%s^7 attempted to wash money in society - ^5%s^7!'):format(source, society))
	end
end)

RegisterServerEvent('esx_society:putVehicleInGarage')
AddEventHandler('esx_society:putVehicleInGarage', function(societyName, vehicle)
	local source = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to put vehicle in non-existing society garage - ^5%s^7!'):format(source, societyName))
		return
	end
	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		table.insert(garage, vehicle)
		store.set('garage', garage)
	end)
end)

RegisterServerEvent('esx_society:removeVehicleFromGarage')
AddEventHandler('esx_society:removeVehicleFromGarage', function(societyName, vehicle)
	local source = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to remove vehicle from non-existing society garage - ^5%s^7!'):format(source, societyName))
		return
	end
	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}

		for i=1, #garage, 1 do
			if garage[i].plate == vehicle.plate then
				table.remove(garage, i)
				break
			end
		end

		store.set('garage', garage)
	end)
end)

ESX.RegisterServerCallback('esx_society:getSocietyMoney', function(source, cb, societyName)
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Player ^5%s^7 attempted to get money from non-existing society - ^5%s^7!'):format(source, societyName))
		return
	end
	if society then
		TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
			cb(account.money)
		end)
	else
		cb(0)
	end
end)

ESX.RegisterServerCallback('esx_society:getEmployees', function(source, cb, society)
	local employees = {}

	local Player = ESX.GetPlayerFromId(source)
	if Player.job.name == society then
		local xPlayers = ESX.GetExtendedPlayers('job', society)
		for _, xPlayer in pairs(xPlayers) do
	
			local name = xPlayer.name
			if Config.EnableESXIdentity and name == GetPlayerName(xPlayer.source) then
				name = xPlayer.get('firstName') .. ' ' .. xPlayer.get('lastName')
			end
	
			table.insert(employees, {
				name = name,
				identifier = xPlayer.identifier,
				job = {
					name = society,
					label = xPlayer.job.label,
					grade = xPlayer.job.grade,
					grade_name = xPlayer.job.grade_name,
					grade_label = xPlayer.job.grade_label
				}
			})
		end
			
		local query = "SELECT identifier, job_grade FROM `users` WHERE `job`= ? ORDER BY job_grade DESC"
	
		if Config.EnableESXIdentity then
			query = "SELECT identifier, job_grade, firstname, lastname FROM `users` WHERE `job`= ? ORDER BY job_grade DESC"
		end
	
		MySQL.query(query, {society},
		function(result)
			for k, row in pairs(result) do
				local alreadyInTable
				local identifier = row.identifier
	
				for k, v in pairs(employees) do
					if v.identifier == identifier then
						alreadyInTable = true
					end
				end
	
				if not alreadyInTable then
					local name = "Name not found." -- maybe this should be a locale instead ¯\_(ツ)_/¯
	
					if Config.EnableESXIdentity then
						name = row.firstname .. ' ' .. row.lastname 
					end
					
					table.insert(employees, {
						name = name,
						identifier = identifier,
						job = {
							name = society,
							label = Jobs[society].label,
							grade = row.job_grade,
							grade_name = Jobs[society].grades[tostring(row.job_grade)].name,
							grade_label = Jobs[society].grades[tostring(row.job_grade)].label
						}
					})
				end
			end
	
			cb(employees)
		end)

	elseif Player.faction.name == society then
		
		local xPlayers = ESX.GetExtendedPlayers('faction', society)
		for _, xPlayer in pairs(xPlayers) do
	
			local name = xPlayer.name
			if Config.EnableESXIdentity and name == GetPlayerName(xPlayer.source) then
				name = xPlayer.get('firstName') .. ' ' .. xPlayer.get('lastName')
			end
	
			table.insert(employees, {
				name = name,
				identifier = xPlayer.identifier,
				faction = {
					name = society,
					label = xPlayer.faction.label,
					grade = xPlayer.faction.grade,
					grade_name = xPlayer.faction.grade_name,
					grade_label = xPlayer.faction.grade_label
				}
			})
		end
			
		local query = "SELECT identifier, faction_grade FROM `users` WHERE `faction`= ? ORDER BY faction_grade DESC"
	
		if Config.EnableESXIdentity then
			query = "SELECT identifier, faction_grade, firstname, lastname FROM `users` WHERE `faction`= ? ORDER BY faction_grade DESC"
		end
	
		MySQL.query(query, {society},
		function(result)
			for k, row in pairs(result) do
				local alreadyInTable
				local identifier = row.identifier
	
				for k, v in pairs(employees) do
					if v.identifier == identifier then
						alreadyInTable = true
					end
				end
	
				if not alreadyInTable then
					local name = "Name not found." -- maybe this should be a locale instead ¯\_(ツ)_/¯
	
					if Config.EnableESXIdentity then
						name = row.firstname .. ' ' .. row.lastname 
					end
					
					table.insert(employees, {
						name = name,
						identifier = identifier,
						faction = {
							name = society,
							label = Factions[society].label,
							grade = row.faction_grade,
							grade_name = Factions[society].grades[tostring(row.faction_grade)].name,
							grade_label = Factions[society].grades[tostring(row.faction_grade)].label
						}
					})
				end
			end
	
			cb(employees)
		end)
	end
end)

ESX.RegisterServerCallback('esx_society:getFaction', function(source, cb, society)
	local faction = json.decode(json.encode(Factions[society]))
	local grades = {}

	for k,v in pairs(faction.grades) do
		table.insert(grades, v)
	end

	table.sort(grades, function(a, b)
		return a.grade < b.grade
	end)

	faction.grades = grades

	cb(faction)
end)

ESX.RegisterServerCallback('esx_society:setFaction', function(source, cb, identifier, faction, grade, type)
	local xPlayer = ESX.GetPlayerFromId(source)
	local isBoss = xPlayer.faction.grade_name == 'boss'

	if isBoss then
		local xTarget = ESX.GetPlayerFromIdentifier(identifier)

		if xTarget then
			xTarget.setFaction(faction, grade)

			if type == 'hire' then
				xTarget.showNotification(_U('you_have_been_hired', faction))
			elseif type == 'promote' then
				xTarget.showNotification(_U('you_have_been_promoted'))
			elseif type == 'fire' then
				xTarget.showNotification(_U('you_have_been_fired', xTarget.getFaction().label))
			end

			cb()
		else
			MySQL.update('UPDATE users SET faction = ?, faction_grade = ? WHERE identifier = ?', {faction, grade, identifier},
			function(rowsChanged)
				cb()
			end)
		end
	else
		print(('esx_society: %s attempted to setFaction'):format(xPlayer.identifier))
		cb()
	end
end)

ESX.RegisterServerCallback('esx_society:setFactionLabel', function(source, cb, faction, grade, label)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.faction.name == faction and xPlayer.faction.grade_name == 'boss' then
			MySQL.update('UPDATE faction_grades SET label = ? WHERE faction_name = ? AND grade = ?', {label, faction, grade},
			function(rowsChanged)
				Factions[faction].grades[tostring(grade)].label = label
				ESX.RefreshFactions()
				Wait(1)
				local xPlayers = ESX.GetExtendedPlayers('faction', faction)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.faction.grade == grade then
						xTarget.setFaction(faction, grade)
					end
				end
				cb()
			end)
	else
		print(('esx_society: %s attempted to setFactionSalary'):format(xPlayer.identifier))
		cb()
	end
end)

ESX.RegisterServerCallback('esx_society:getJob', function(source, cb, society)
	local job = json.decode(json.encode(Jobs[society]))
	local grades = {}

	for k,v in pairs(job.grades) do
		table.insert(grades, v)
	end

	table.sort(grades, function(a, b)
		return a.grade < b.grade
	end)

	job.grades = grades

	cb(job)
end)

ESX.RegisterServerCallback('esx_society:setJob', function(source, cb, identifier, job, grade, type)
	local xPlayer = ESX.GetPlayerFromId(source)
	local isBoss = xPlayer.job.grade_name == 'boss'
	local xTarget = ESX.GetPlayerFromIdentifier(identifier)

	if isBoss then

		if xTarget then
			xTarget.setJob(job, grade)

			if type == 'hire' then
				xTarget.showNotification(TranslateCap('you_have_been_hired', job))
				xPlayer.showNotification(TranslateCap("you_have_hired", xTarget.getName()))
			elseif type == 'promote' then
				xTarget.showNotification(TranslateCap('you_have_been_promoted'))
				xPlayer.showNotification(TranslateCap("you_have_promoted", xTarget.getName()))
			elseif type == 'fire' then
				xTarget.showNotification(TranslateCap('you_have_been_fired', xTarget.getJob().label))
				xPlayer.showNotification(TranslateCap("you_have_fired", xTarget.getName()))
			end

			cb()
		else
			MySQL.update('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {job, grade, identifier},
			function(rowsChanged)
				cb()
			end)
		end
	else
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJob for Player ^5%s^7!'):format(source, xTarget.source))
		cb()
	end
end)


ESX.RegisterServerCallback('esx_society:setJobSalary', function(source, cb, job, grade, salary)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name == job and xPlayer.job.grade_name == 'boss' then
		if salary <= Config.MaxSalary then
			MySQL.update('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', {salary, job, grade},
			function(rowsChanged)
				Jobs[job].grades[tostring(grade)].salary = salary
				ESX.RefreshJobs()
				Wait(1)
				local xPlayers = ESX.GetExtendedPlayers('job', job)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.job.grade == grade then
						xTarget.setJob(job, grade)
					end
				end
				cb()
			end)
		else
			print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary over the config limit for ^5%s^7!'):format(source, job))
			cb()
		end
	else
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobSalary for ^5%s^7!'):format(source, job))
		cb()
	end
end)

ESX.RegisterServerCallback('esx_society:setFactionSalary', function(source, cb, faction, grade, salary)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.faction.name == faction and xPlayer.faction.grade_name == 'boss' then
		if salary <= Config.MaxSalary then
			MySQL.update('UPDATE faction_grades SET salary = ? WHERE faction_name = ? AND grade = ?', {salary, faction, grade},
			function(rowsChanged)
				Factions[faction].grades[tostring(grade)].salary = salary
				ESX.RefreshFactions()
				Wait(1)
				local xPlayers = ESX.GetExtendedPlayers('faction', faction)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.faction.grade == grade then
						xTarget.setFaction(faction, grade)
					end
				end
				cb()
			end)
		else
			print(('esx_society: %s attempted to setFactionSalary over config limit!'):format(xPlayer.identifier))
			cb()
		end
	else
		print(('esx_society: %s attempted to setFactionSalary'):format(xPlayer.identifier))
		cb()
	end
end)


ESX.RegisterServerCallback('esx_society:setJobLabel', function(source, cb, job, grade, label)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.job.name == job and xPlayer.job.grade_name == 'boss' then
			MySQL.update('UPDATE job_grades SET label = ? WHERE job_name = ? AND grade = ?', {label, job, grade},
			function(rowsChanged)
				Jobs[job].grades[tostring(grade)].label = label
				ESX.RefreshJobs()
				Wait(1)
				local xPlayers = ESX.GetExtendedPlayers('job', job)
				for _, xTarget in pairs(xPlayers) do

					if xTarget.job.grade == grade then
						xTarget.setJob(job, grade)
					end
				end
				cb()
			end)
	else
		print(('[^3WARNING^7] Player ^5%s^7 attempted to setJobLabel for ^5%s^7!'):format(source, job))
		cb()
	end
end)

local getOnlinePlayers, onlinePlayers = false, {}
ESX.RegisterServerCallback('esx_society:getOnlinePlayers', function(source, cb)
	if getOnlinePlayers == false and next(onlinePlayers) == nil then -- Prevent multiple xPlayer loops from running in quick succession
		getOnlinePlayers, onlinePlayers = true, {}
		
		local xPlayers = ESX.GetExtendedPlayers()
		for i=1, #(xPlayers) do 
			local xPlayer = xPlayers[i]
			table.insert(onlinePlayers, {
				source = xPlayer.source,
				identifier = xPlayer.identifier,
				name = xPlayer.name,
				job = xPlayer.job,
				faction = xPlayer.faction,
			})
		end
		cb(onlinePlayers)
		getOnlinePlayers = false
		Wait(1000) -- For the next second any extra requests will receive the cached list
		onlinePlayers = {}
		return
	end
	while getOnlinePlayers do Wait(0) end -- Wait for the xPlayer loop to finish
	cb(onlinePlayers)
end)

ESX.RegisterServerCallback('esx_society:getVehiclesInGarage', function(source, cb, societyName)
	local society = GetSociety(societyName)
	if not society then
		print(('[^3WARNING^7] Attempting To get a non-existing society - %s!'):format(societyName))
		return
	end
	TriggerEvent('esx_datastore:getSharedDataStore', society.datastore, function(store)
		local garage = store.get('garage') or {}
		cb(garage)
	end)
end)

ESX.RegisterServerCallback('esx_society:isBoss', function(source, cb, society)
	cb(isPlayerBoss(source, society))
end)

function isPlayerBoss(playerId, society)
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if (xPlayer.job.name == society and xPlayer.job.grade_name == 'boss') or (xPlayer.faction.name == society and xPlayer.faction.grade_name == 'boss') then
		return true
	else
		print(('esx_society: %s attempted open a society boss menu!'):format(xPlayer.identifier))
		return false
	end
end

function WashMoneyCRON(d, h, m)
	MySQL.query('SELECT * FROM society_moneywash', function(result)
		for i=1, #result, 1 do
			local society = GetSociety(result[i].society)
			local xPlayer = ESX.GetPlayerFromIdentifier(result[i].identifier)

			-- add society money
			TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
				account.addMoney(result[i].amount)
			end)

			-- send notification if player is online
			if xPlayer then
				xPlayer.showNotification(TranslateCap('you_have_laundered', ESX.Math.GroupDigits(result[i].amount)))
			end

		end
		MySQL.update('DELETE FROM society_moneywash')
	end)
end

TriggerEvent('cron:runAt', 3, 0, WashMoneyCRON)
