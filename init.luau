local FrameChecker = {}

local RunService = game:GetService("RunService")

local FrameUpdateTable = {}
local LastIteration, Start = 0, os.clock()

local FPS = if RunService:IsClient() then 240 else 60
local MIN_FRAME_TIME = 1/60
local THROTTLE_SERVER = false -- Server has a constant 60 fps so we don't need to check for fps changes unless you want to throttle if server is lagging

local FrameTime = 1 / (FPS + 10)
local FrameStart = os.clock()

local YieldedThreads = {}

FrameChecker.yieldedThreads = YieldedThreads
FrameChecker.FPS = FPS
FrameChecker.FrameStart = FrameStart
FrameChecker.FrameTime = FrameTime

local function inTolerance(value, target)
	local tolerance = 5
	if target > 200 then
		tolerance = 10
	end

	return value >= target - tolerance and value <= target + tolerance
end

local function getTimeTolerance(value)
	if value > 180 then
		return 0.5
	elseif value > 100 then
		return 1.5
	end
	return 2
end

local function getFPS()
	LastIteration = os.clock()
	for Index = #FrameUpdateTable, 1, -1 do
		FrameUpdateTable[Index + 1] = FrameUpdateTable[Index] >= LastIteration - 1 and FrameUpdateTable[Index] or nil
	end

	FrameUpdateTable[1] = LastIteration
	return math.floor(LastIteration - Start >= 1 and #FrameUpdateTable or #FrameUpdateTable / (LastIteration - Start))
end

local changingStartTime = 0
local newFPS
local function update()
	FrameStart = os.clock()
	FrameChecker.FrameStart = FrameStart
	local fps = getFPS()

	if inTolerance(fps, FPS) then
		changingStartTime = os.clock()
		return
	elseif not newFPS or not inTolerance(fps, newFPS) then
		newFPS = fps
		changingStartTime = os.clock()
		return
	elseif inTolerance(fps, newFPS) and os.clock() - changingStartTime < getTimeTolerance(newFPS) then
		return
	end

	newFPS = nil
	FPS = fps
	FrameTime = math.max(MIN_FRAME_TIME, 1 / (FPS + 10))
	FrameChecker.FPS = FPS
	FrameChecker.FrameTime = FrameTime
end

function FrameChecker.getFPS()
	return FPS
end

function FrameChecker.checkOutsideFrame(cost: number?)
	return os.clock() - FrameStart + (cost or 0) > FrameTime
end

function FrameChecker.yieldThread(group)
	if YieldedThreads[group] then
		error(`A thread with the group "{group}" has already been yielded. There can only be one yielded thread per group.`)
	end
	YieldedThreads[group] = coroutine.running()
	coroutine.yield()
end

function FrameChecker.resumeThread(group)
	if not YieldedThreads[group] then
		return false
	end
	local thread = YieldedThreads[group]
	YieldedThreads[group] = nil
	task.spawn(thread)
	return true
end

function FrameChecker.hasYieldedThread(group)
	return YieldedThreads[group] ~= nil
end

function FrameChecker.getYieldedThread(group)
	return YieldedThreads[group]
end

if RunService:IsClient() and RunService:IsStudio() then
	-- For some reason Rendering Runs last instead of first now...
	RunService.PreAnimation:Connect(update) -- This is supposed to be RenderStepped but its bugged  ¯\_(ツ)_/¯
elseif RunService:IsServer() then
	RunService.PreAnimation:Connect(function() 
		if not THROTTLE_SERVER then
			FrameStart = os.clock() 
			FrameChecker.FrameStart = FrameStart
		else
			update()
		end
	end)
else
	RunService.PreAnimation:Connect(update) -- mobile devices have inconsistent frame rates as well AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
end

return FrameChecker
