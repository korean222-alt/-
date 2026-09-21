--[[
	Main
	서버 진입점. 서비스들을 순서대로 켜는 일만 한다.

	위치: ServerScriptService > CursedBarrel > Main  (Script)
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("CursedBarrel"):WaitForChild("Services")
local TableService = require(Services.TableService)

TableService:Start()

print("[CursedBarrel] 서버 부팅 완료 (Phase 1: 테이블 참가 시스템)")
