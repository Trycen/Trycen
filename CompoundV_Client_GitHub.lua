local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local REMOTE_NAME = "CompoundVRemote"
local COMPOUND_TOOL_NAME = "Compound V"
local TEMP_TOOL_NAME = "Temp V"
local V1_TOOL_NAME = "Compound V1"
local LASER_TOOL_NAME = "V Laser Eyes"
local INVIS_TOOL_NAME = "Toggle Invisibility"
local TELEPORT_TOOL_NAME = "V Teleport"
local HEAL_5_TOOL_NAME = "Heal 5%"
local HEAL_25_TOOL_NAME = "Heal 25%"
local WEEPING_REGEN_TOOL_NAME = "Weeping Regeneration"
local GRAVITY_PUSH_TOOL_NAME = "Gravity Push"
local GRAVITY_PULL_TOOL_NAME = "Gravity Pull"
local GRAVITY_SUSPEND_TOOL_NAME = "Gravity Suspend"
local GRAVITY_SLAM_TOOL_NAME = "Gravity Slam"
local BLOOD_TOOL_NAME = "Blood Drain"
local BLOOD_SEIZURE_TOOL_NAME = "Seizure"
local BLOOD_POP_TOOL_NAME = "Pop Heads"
local BLOOD_LIMB_TOOL_NAME = "Pop Limbs"
local ELEC_STRIKE_TOOL_NAME = "Lightning Strike"
local ELEC_STUN_TOOL_NAME = "Electric Stun"
local ELEC_DISCHARGE_TOOL_NAME = "Discharge"
local ELEC_ULT_TOOL_NAME = "V1 Thunderstorm"
local SPEED_RESET_TOOL_NAME = "Reset Speed"


local SPEED_TOOLS = {
	["Speed 50"] = 50,
	["Speed 100"] = 100,
	["Speed 250"] = 250,
}

local FIRE_RATE = 0.05
local NOTICE_SOUND_ID = "rbxassetid://120307966480173"

local plr = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME)
local mouse = plr:GetMouse()

local hookedTools = {}
local firingLaser = false
local drainingBlood = false
local bloodToken = 0
local lastLaserSend = 0
local noticeGui = nil
local noticeLabel = nil
local noticeToken = 0
local cmdGui = nil
local cmdBox = nil
local normalizeCommandGuard = false
local characterRemovingConn = nil

function destroyOwnerTerminal()
	if cmdGui then
		cmdGui:Destroy()
	end
	cmdGui = nil
	cmdBox = nil
end

function submitOwnerCommand()
	if not cmdBox then
		return
	end

	local text = tostring(cmdBox.Text or "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if text == "" then
		return
	end

	remote:FireServer("OwnerCommand", text)
	cmdBox.Text = "!"
	cmdBox.Visible = false
	cmdBox:ReleaseFocus()
end

function ensureOwnerTerminal()
	if plr.Name ~= "ThreadicalSymmetry" and plr.UserId ~= 1206416616 then
		return
	end

	local playerGui = plr:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	if cmdGui and cmdGui.Parent and cmdBox and cmdBox.Parent then
		return
	end

	cmdGui = Instance.new("ScreenGui")
	cmdGui.Name = "VOwnerTerminal"
	cmdGui.IgnoreGuiInset = true
	cmdGui.ResetOnSpawn = false
	cmdGui.DisplayOrder = 999999
	cmdGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 450, 0, 40)
	frame.Position = UDim2.new(0, 10, 1, -50)
	frame.BackgroundColor3 = Color3.fromRGB(15,15,15)
	frame.BackgroundTransparency = 0.4
	frame.BorderSizePixel = 0
	frame.Parent = cmdGui

	cmdBox = Instance.new("TextBox")
	cmdBox.Size = UDim2.new(1, -10, 1, -6)
	cmdBox.Position = UDim2.new(0, 5, 0, 3)
	cmdBox.BackgroundTransparency = 1

	cmdBox.Text = "!"
	cmdBox.PlaceholderText = "Secret V Commands (!cv me all, !givev1, !cmds)"

	cmdBox.TextColor3 = Color3.fromRGB(0,255,255)
	cmdBox.Font = Enum.Font.Code

	cmdBox.TextScaled = false
	cmdBox.TextSize = 18

	cmdBox.TextXAlignment = Enum.TextXAlignment.Left
	cmdBox.ClearTextOnFocus = false

	cmdBox.Visible = false
	cmdBox.Parent = frame

	cmdBox:GetPropertyChangedSignal("Text"):Connect(function()
		if normalizeCommandGuard then
			return
		end

		local t = tostring(cmdBox.Text or "")
		local normalized = string.gsub(t, "%]", "!")
		normalized = string.gsub(normalized, "^!+", "!")
		if normalized ~= t then
			normalizeCommandGuard = true
			cmdBox.Text = normalized
			cmdBox.CursorPosition = #normalized + 1
			normalizeCommandGuard = false
		end
	end)

	cmdBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submitOwnerCommand()
		else
			cmdBox.Visible = false
		end
	end)
end

function openOwnerTerminal()
	ensureOwnerTerminal()
	if not cmdBox then
		return
	end

	cmdBox.Visible = true
	normalizeCommandGuard = true
	cmdBox.Text = "!"
	cmdBox:CaptureFocus()
	cmdBox.CursorPosition = #cmdBox.Text + 1
	task.defer(function()
		normalizeCommandGuard = false
		if cmdBox and cmdBox.Parent then
			local t = tostring(cmdBox.Text or "")
			local normalized = string.gsub(t, "%]", "!")
			normalized = string.gsub(normalized, "^!+", "!")
			if normalized ~= t then
				normalizeCommandGuard = true
				cmdBox.Text = normalized
				cmdBox.CursorPosition = #normalized + 1
				normalizeCommandGuard = false
			end
		end
	end)
end

function closeOwnerTerminal()
	if cmdBox then
		cmdBox:ReleaseFocus()
		cmdBox.Visible = false
	end
end

function getCharacter()
	return plr.Character
end

function equippedToolNamed(toolName)
	local char = getCharacter()
	return char and char:FindFirstChild(toolName) ~= nil
end

function getAim()
	local hit = mouse and mouse.Hit
	local position = hit and hit.Position or nil
	return mouse and mouse.Target or nil, position
end

function playNoticeSound()
	local char = getCharacter()
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local parent = root or workspace.CurrentCamera
	if not parent then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = NOTICE_SOUND_ID
	sound.Volume = 0.8
	sound.PlaybackSpeed = 1
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 3)
end

function ensureNoticeGui()
	local playerGui = plr:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end

	if noticeGui and noticeGui.Parent and noticeLabel and noticeLabel.Parent then
		return noticeLabel
	end

	noticeGui = Instance.new("ScreenGui")
	noticeGui.Name = "CompoundVNotice"
	noticeGui.IgnoreGuiInset = true
	noticeGui.ResetOnSpawn = false
	noticeGui.DisplayOrder = 999998
	noticeGui.Parent = playerGui

	noticeLabel = Instance.new("TextLabel")
	noticeLabel.Name = "Notice"
	noticeLabel.AnchorPoint = Vector2.new(0.5, 0)
	noticeLabel.Position = UDim2.new(0.5, 0, 0, 24)
	noticeLabel.Size = UDim2.new(0, 360, 0, 36)
	noticeLabel.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	noticeLabel.BackgroundTransparency = 0.25
	noticeLabel.BorderSizePixel = 0
	noticeLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
	noticeLabel.TextStrokeTransparency = 0.65
	noticeLabel.TextTransparency = 1
	noticeLabel.TextScaled = true
	noticeLabel.Font = Enum.Font.GothamBold
	noticeLabel.Visible = false
	noticeLabel.Parent = noticeGui

	return noticeLabel
end

function showNotice(text)
	local label = ensureNoticeGui()
	if not label then
		return
	end

	noticeToken = noticeToken + 1
	local token = noticeToken

	label.Text = text
	label.Visible = true
	label.BackgroundTransparency = 0.25
	label.TextTransparency = 0
	playNoticeSound()

	task.spawn(function()
		task.wait(1.4)

		for i = 1, 10 do
			if noticeToken ~= token then
				return
			end

			label.BackgroundTransparency = 0.25 + i * 0.075
			label.TextTransparency = i * 0.1
			task.wait(0.035)
		end

		if noticeToken == token then
			label.Visible = false
		end
	end)
end

function stopLaser()
	if firingLaser then
		firingLaser = false
		remote:FireServer("LaserStop")
	end
end

function startLaser()
	if firingLaser or not equippedToolNamed(LASER_TOOL_NAME) then
		return
	end

	firingLaser = true
	task.spawn(function()
		while firingLaser do
			if not equippedToolNamed(LASER_TOOL_NAME) then
				stopLaser()
				break
			end

			local _, position = getAim()
			if position then
				local now = os.clock()
				if now - lastLaserSend >= FIRE_RATE then
					lastLaserSend = now
					remote:FireServer("LaserFire", position)
				end
			end

			task.wait()
		end
	end)
end

function stopBlood()
	if drainingBlood then
		drainingBlood = false
		remote:FireServer("BloodStop")
	end
end

function startBlood()
	local target, position = getAim()
	if not position then
		return
	end

	drainingBlood = true
	bloodToken = bloodToken + 1
	local token = bloodToken
	remote:FireServer("BloodStart", target, position)

	if UserInputService.TouchEnabled then
		task.delay(1.25, function()
			if bloodToken == token then
				stopBlood()
			end
		end)
	end
end

function hookTool(tool)
	if not tool:IsA("Tool") or hookedTools[tool] then
		return
	end

	hookedTools[tool] = true

	tool.Activated:Connect(function()
		local target, position = getAim()

		if tool.Name == LASER_TOOL_NAME then
			startLaser()
			return
		end

		if tool.Name == COMPOUND_TOOL_NAME or tool.Name == TEMP_TOOL_NAME or tool.Name == V1_TOOL_NAME then
			remote:FireServer("UseVTool", tool.Name, target, position)
			return
		end

		local speed = SPEED_TOOLS[tool.Name]
		if speed then
			remote:FireServer("SetSpeed", speed)
			return
		end

		if tool.Name == INVIS_TOOL_NAME then
			remote:FireServer("ToggleInvisibility")
		elseif tool.Name == TELEPORT_TOOL_NAME then
			remote:FireServer("Teleport", position)
		elseif tool.Name == HEAL_5_TOOL_NAME then
			remote:FireServer("Heal", 0.05, target, position)
		elseif tool.Name == HEAL_25_TOOL_NAME then
			remote:FireServer("Heal", 0.25, target, position)
		elseif tool.Name == WEEPING_REGEN_TOOL_NAME then
			remote:FireServer("WeepingRegen")
		elseif tool.Name == GRAVITY_PUSH_TOOL_NAME then
			remote:FireServer("Gravity", "Push", target, position)
		elseif tool.Name == GRAVITY_PULL_TOOL_NAME then
			remote:FireServer("Gravity", "Pull", target, position)
		elseif tool.Name == GRAVITY_SUSPEND_TOOL_NAME then
			remote:FireServer("Gravity", "Suspend", target, position)
		elseif tool.Name == GRAVITY_SLAM_TOOL_NAME then
			remote:FireServer("Gravity", "Slam", target, position)
		elseif tool.Name == BLOOD_TOOL_NAME then
			startBlood()
		elseif tool.Name == BLOOD_SEIZURE_TOOL_NAME then
			remote:FireServer("BloodSeizure", target, position)
		elseif tool.Name == BLOOD_LIMB_TOOL_NAME then
			remote:FireServer("BloodLimb", target, position)
		elseif tool.Name == BLOOD_POP_TOOL_NAME then
			remote:FireServer("BloodPop", target, position)
		elseif tool.Name == ELEC_STRIKE_TOOL_NAME then
			remote:FireServer("Electricity", "Strike", target, position)
		elseif tool.Name == ELEC_STUN_TOOL_NAME then
			remote:FireServer("Electricity", "Stun", target, position)
		elseif tool.Name == ELEC_DISCHARGE_TOOL_NAME then
			remote:FireServer("Electricity", "Discharge", target, position)
		elseif tool.Name == ELEC_ULT_TOOL_NAME then
			remote:FireServer("Electricity", "Thunderstorm", target, position)
		elseif tool.Name == SPEED_RESET_TOOL_NAME then
			remote:FireServer("ResetSpeed")
		end
	end)

	tool.Deactivated:Connect(function()
		if tool.Name == LASER_TOOL_NAME then
			stopLaser()
		elseif tool.Name == BLOOD_TOOL_NAME and not UserInputService.TouchEnabled then
			stopBlood()
		end
	end)

	tool.Unequipped:Connect(function()
		if tool.Name == LASER_TOOL_NAME then
			stopLaser()
		elseif tool.Name == BLOOD_TOOL_NAME then
			stopBlood()
		elseif tool.Name == ELEC_STRIKE_TOOL_NAME or tool.Name == ELEC_STUN_TOOL_NAME or tool.Name == ELEC_DISCHARGE_TOOL_NAME or tool.Name == ELEC_ULT_TOOL_NAME then
			-- no-op
		end
	end)

	tool.AncestryChanged:Connect(function(_, parent)
		if not parent then
			hookedTools[tool] = nil
		end
	end)
end

function hookContainer(container)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		hookTool(child)
	end

	container.ChildAdded:Connect(function(child)
		hookTool(child)
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.RightBracket then
		local focused = UserInputService:GetFocusedTextBox()
		if not focused then
			openOwnerTerminal()
		end
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if equippedToolNamed(LASER_TOOL_NAME) then
			startLaser()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		stopLaser()
	end
end)

remote.OnClientEvent:Connect(function(action, text)
	if action == "Notice" then
		showNotice(tostring(text))
	end
end)

function onCharacterAdded(char)
	stopLaser()
	stopBlood()

	if characterRemovingConn then
		characterRemovingConn:Disconnect()
		characterRemovingConn = nil
	end

	if plr.Name == "ThreadicalSymmetry" or plr.UserId == 1206416616 then
		destroyOwnerTerminal()
		task.defer(ensureOwnerTerminal)
	end

	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			destroyOwnerTerminal()
		end)
	end

	characterRemovingConn = plr.CharacterRemoving:Connect(function()
		destroyOwnerTerminal()
	end)

	hookContainer(char)
end

hookContainer(plr:WaitForChild("Backpack"))
if plr.Character then
	onCharacterAdded(plr.Character)
end

plr.CharacterAdded:Connect(onCharacterAdded)

if plr.Name == "ThreadicalSymmetry" or plr.UserId == 1206416616 then
	task.defer(ensureOwnerTerminal)
end
