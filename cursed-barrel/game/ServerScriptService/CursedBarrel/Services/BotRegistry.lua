--[[
	BotRegistry  (Phase 11)
	AI 선원의 몸(Model)과 AI 표(BotService 가 만든 것)를 잇는 작은 명부.

	GameTable 은 의자에 앉은 몸을 보고 "누구인지"를 알아야 한다.
	사람은 Players:GetPlayerFromCharacter 로 알 수 있지만 AI 는 Players 에 없다.
	그래서 BotService 가 여기에 적어 두고, GameTable 이 여기서 찾는다.
	(서로를 require 하면 순환이 생기므로 둘 다 이 모듈만 본다)
]]

local BotRegistry = {}

local byCharacter = {} -- [Model] = bot

function BotRegistry.register(character, bot)
	byCharacter[character] = bot
end

function BotRegistry.unregister(character)
	byCharacter[character] = nil
end

function BotRegistry.fromCharacter(character)
	return character and byCharacter[character] or nil
end

return BotRegistry
