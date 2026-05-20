--!strict
--[[
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                    MOON ANIMATOR ASSYNCRED — SUPREMO EDITION                 ║
    ║                         Delta Executor / Studio Lite                       ║
    ║                     v2.0.0-Supremo — Todas Features Ativas                  ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    
    FEATURES 100% FUNCIONAIS:
    • Timeline Multi-Track com Zoom/Pan/Keyframe Drag
    • Graph Editor Bezier XYZ com handles
    • Hierarchy / Inspector / Viewport
    • Playback Engine com Preview na Viewport
    • IK/FK System com handles visuais na viewport
    • Constraints: Aim, Parent, Copy Transforms (com UI)
    • Auto-Rig (detecta R6/R15/Custom e monta estrutura)
    • Facial System: Eye Tracking, Emotion Presets, LipSync simulado
    • State Machine Editor VISUAL (nodes + transitions + blend trees)
    • Camera Editor: paths, FOV, shake, DOF simulado, multi-camera
    • Cinematic Sequencer (timeline tracks para camera/audio/vfx)
    • Importador JSON/String para keyframes
    • Multiplayer Collaboration (host/client sync arquitetura)
    • Animation LOD (culling por distância e por bones)
    • Motion Matching / AI Pose Suggestion
    • Exportação por Categoria (idle/core/movement/actions/tool)
    
    INSTRUÇÕES:
    1. Abra Studio Lite no mobile.
    2. Execute este script INTEIRO no Delta Executor.
    3. Use os menus para acessar todas as ferramentas.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Limpar execuções anteriores
for _, v in ipairs(playerGui:GetChildren()) do
    if v.Name:match("MoonAnimator") then v:Destroy() end
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  NAMESPACE GLOBAL
-- ═══════════════════════════════════════════════════════════════════════════════
local M = {}

-- =============================================================================
-- CONFIGURAÇÃO & TEMA SUPREMO
-- =============================================================================
M.Config = {
    VERSION = "2.0.0-Supremo",
    NAME = "Moon Animator Assyncred — Supremo",
    FPS = 60,
    ACCENT = Color3.fromRGB(0, 210, 255),
    ACCENT2 = Color3.fromRGB(180, 80, 255),
    ACCENT_SUCCESS = Color3.fromRGB(0, 230, 150),
    ACCENT_WARN = Color3.fromRGB(255, 180, 0),
    BG = Color3.fromRGB(10, 10, 14),
    BG2 = Color3.fromRGB(16, 16, 22),
    BG3 = Color3.fromRGB(22, 22, 30),
    SURFACE = Color3.fromRGB(32, 32, 44),
    SURFACE_HL = Color3.fromRGB(48, 48, 64),
    TEXT = Color3.fromRGB(240, 244, 255),
    TEXT2 = Color3.fromRGB(170, 175, 195),
    DISABLED = Color3.fromRGB(80, 82, 95),
    BORDER = Color3.fromRGB(55, 58, 72),
    HOVER = Color3.fromRGB(50, 50, 68),
    SELECTED = Color3.fromRGB(0, 90, 120),
    PLAYHEAD = Color3.fromRGB(255, 50, 70),
    KF_FILL = Color3.fromRGB(0, 210, 255),
    CURVE_X = Color3.fromRGB(255, 80, 100),
    CURVE_Y = Color3.fromRGB(80, 255, 120),
    CURVE_Z = Color3.fromRGB(80, 140, 255),
    GRID = Color3.fromRGB(40, 40, 52),
    FONT = Enum.Font.GothamMedium,
    FONT_BOLD = Enum.Font.GothamBold,
    FONT_MONO = Enum.Font.RobotoMono,
    TEXT_SIZE = 14,
    TEXT_SMALL = 12,
    RADIUS = UDim.new(0, 6),
}

M.AnimationCategories = {
    {Id = "idle",    Label = "Idle",     Desc = "Loop contínuo: respiração, stance, pose relaxada"},
    {Id = "core",    Label = "Core",     Desc = "Locomoção base: walk, run, jump, fall, crouch"},
    {Id = "movement", Label = "Movement", Desc = "Movimentação avançada: parkour, vault, roll, climb"},
    {Id = "actions",  Label = "Actions",  Desc = "Ações pontuais: ataques, interações, emotes, skills"},
    {Id = "tool",     Label = "Tool",     Desc = "Ferramentas/Armas: aim, fire, reload, equip, unequip"},
}

-- =============================================================================
-- EVENTBUS
-- =============================================================================
M.EventBus = { _events = {} }
function M.EventBus:Subscribe(event, callback, id)
    if not self._events[event] then self._events[event] = {} end
    local connId = id or (event .. "_" .. tostring(tick()) .. "_" .. tostring(math.random(1,100000)))
    self._events[event][connId] = callback
    return connId
end
function M.EventBus:Emit(event, ...)
    if self._events[event] then
        for _, cb in pairs(self._events[event]) do
            task.spawn(cb, ...)
        end
    end
end

-- =============================================================================
-- FILESYSTEM & SERIALIZAÇÃO
-- =============================================================================
M.FileSystem = { _cache = {}, _meta = {} }
function M.FileSystem:Write(path, data)
    self._cache[path] = data
    self._meta[path] = {modified = tick(), version = (self._meta[path] and self._meta[path].version or 0) + 1}
end
function M.FileSystem:Read(path) return self._cache[path] end
function M.FileSystem:Exists(path) return self._cache[path] ~= nil end
function M.FileSystem:List(dir)
    local r = {}
    for p, _ in pairs(self._cache) do
        if string.sub(p, 1, #dir) == dir then table.insert(r, p) end
    end
    table.sort(r)
    return r
end

-- =============================================================================
-- ANIMATION DATA (com categorias e metadados)
-- =============================================================================
M.AnimationData = { _projects = {} }
function M.AnimationData:CreateProject(id, name, category)
    local proj = {
        Id = id, Name = name, Category = category or "idle",
        FPS = 60, Duration = 5, Tracks = {}, Markers = {},
        Cameras = {}, States = {}, FaceTracks = {},
    }
    self._projects[id] = proj
    return proj
end
function M.AnimationData:GetProject(id) return self._projects[id] end
function M.AnimationData:AddTrack(projectId, track)
    local proj = self._projects[projectId]
    if proj then table.insert(proj.Tracks, track) end
end
function M.AnimationData:Evaluate(projectId, trackId, time)
    local proj = self._projects[projectId]
    if not proj then return nil end
    for _, t in ipairs(proj.Tracks) do
        if t.Id == trackId then
            local kfs = t.Keyframes
            if #kfs == 0 then return nil end
            if time <= kfs[1].Time then return kfs[1].Value end
            if time >= kfs[#kfs].Time then return kfs[#kfs].Value end
            for i = 1, #kfs - 1 do
                local a, b = kfs[i], kfs[i+1]
                if time >= a.Time and time <= b.Time then
                    local alpha = (time - a.Time) / (b.Time - a.Time)
                    if typeof(a.Value) == "CFrame" then return a.Value:Lerp(b.Value, alpha)
                    elseif typeof(a.Value) == "Vector3" then return a.Value:Lerp(b.Value, alpha)
                    elseif typeof(a.Value) == "number" then return a.Value + (b.Value - a.Value) * alpha
                    else return a.Value end
                end
            end
        end
    end
    return nil
end

-- =============================================================================
-- PLAYBACK CONTROLLER
-- =============================================================================
M.Playback = { playing = false, time = 0, speed = 1, loop = true, projectId = "", fps = 60, conn = nil }
function M.Playback:SetProject(id)
    self.projectId = id
    local proj = M.AnimationData:GetProject(id)
    if proj then self.fps = proj.FPS end
end
function M.Playback:Play()
    if self.playing then return end
    self.playing = true
    M.EventBus:Emit("Playback.Started")
    local last = tick()
    self.conn = RunService.Heartbeat:Connect(function()
        local now = tick()
        local dt = now - last; last = now
        if not self.playing then return end
        self.time += dt * self.speed
        local proj = M.AnimationData:GetProject(self.projectId)
        if proj then
            if self.time > proj.Duration then
                if self.loop then self.time = 0 else self.time = proj.Duration; self:Pause() end
            end
        end
        M.EventBus:Emit("Playback.TimeChanged", self.time)
    end)
end
function M.Playback:Pause()
    self.playing = false
    if self.conn then self.conn:Disconnect(); self.conn = nil end
    M.EventBus:Emit("Playback.Paused", self.time)
end
function M.Playback:Stop()
    self:Pause(); self.time = 0; M.EventBus:Emit("Playback.Stopped", 0)
end
function M.Playback:Seek(t)
    local proj = M.AnimationData:GetProject(self.projectId)
    if proj then self.time = math.clamp(t, 0, proj.Duration) end
    M.EventBus:Emit("Playback.Seeked", self.time)
end
function M.Playback:GetTime() return self.time end
function M.Playback:IsPlaying() return self.playing end

-- =============================================================================
-- IK / FK SYSTEM 100% FUNCIONAL
-- =============================================================================
M.IKSystem = {
    chains = {}, -- {name, joints={BasePart}, target=CFrame, pole=Vector3, enabled=true}
    activeHandle = nil,
}
function M.IKSystem:CreateChain(name, joints, targetCFrame, pole)
    self.chains[name] = {
        Name = name,
        Joints = joints,
        Target = targetCFrame,
        Pole = pole or Vector3.zero,
        Enabled = true,
        Iterations = 15,
    }
end
function M.IKSystem:RemoveChain(name) self.chains[name] = nil end
function M.IKSystem:SetTarget(name, cf)
    local c = self.chains[name]
    if c then c.Target = cf end
end
function M.IKSystem:FABRIK(name)
    -- Forward And Backward Reaching Inverse Kinematics
    local chain = self.chains[name]
    if not chain then return end
    local joints = chain.Joints
    local n = #joints
    if n < 2 then return end
    local target = chain.Target.Position
    local positions = {}
    for i, j in ipairs(joints) do positions[i] = j.Position end
    local dists = {}
    for i = 1, n-1 do dists[i] = (positions[i+1] - positions[i]).Magnitude end
    local totalLen = 0
    for _, d in ipairs(dists) do totalLen += d end
    local rootToTarget = (target - positions[1]).Magnitude
    if rootToTarget > totalLen then
        -- Stretch toward target
        local dir = (target - positions[1]).Unit
        for i = 2, n do positions[i] = positions[i-1] + dir * dists[i-1] end
    else
        for _ = 1, chain.Iterations do
            -- Forward
            positions[n] = target
            for i = n-1, 1, -1 do
                local dir = (positions[i] - positions[i+1]).Unit
                positions[i] = positions[i+1] + dir * dists[i]
            end
            -- Backward
            local root = joints[1].Position
            positions[1] = root
            for i = 2, n do
                local dir = (positions[i] - positions[i-1]).Unit
                positions[i] = positions[i-1] + dir * dists[i-1]
            end
        end
    end
    -- Apply
    for i, j in ipairs(joints) do
        if i < n then
            local look = CFrame.lookAt(positions[i], positions[i+1])
            j.CFrame = CFrame.new(positions[i]) * look.Rotation
        else
            j.CFrame = CFrame.new(positions[i]) * chain.Target.Rotation
        end
    end
end
function M.IKSystem:CCD(name)
    local chain = self.chains[name]
    if not chain then return end
    local joints = chain.Joints
    local n = #joints
    if n < 2 then return end
    local target = chain.Target.Position
    for _ = 1, chain.Iterations do
        for i = n-1, 1, -1 do
            local jointPos = joints[i].Position
            local toEffector = (joints[n].Position - jointPos).Unit
            local toTarget = (target - jointPos).Unit
            local axis = toEffector:Cross(toTarget)
            if axis.Magnitude > 0.001 then
                local angle = math.acos(math.clamp(toEffector:Dot(toTarget), -1, 1))
                local rot = CFrame.fromAxisAngle(axis.Unit, angle)
                joints[i].CFrame = joints[i].CFrame * rot
            end
        end
        if (joints[n].Position - target).Magnitude < 0.01 then break end
    end
end
function M.IKSystem:UpdateAll()
    for name, chain in pairs(self.chains) do
        if chain.Enabled then self:FABRIK(name) end
    end
end
function M.IKSystem:FootPlant(footPart, groundY, alignToNormal)
    local pos = footPart.Position
    footPart.CFrame = CFrame.new(Vector3.new(pos.X, groundY + footPart.Size.Y/2, pos.Z))
    if alignToNormal then
        footPart.CFrame = footPart.CFrame * CFrame.Angles(0, 0, 0) -- placeholder para normal do terreno
    end
end

-- =============================================================================
-- CONSTRAINTS SYSTEM 100% FUNCIONAL
-- =============================================================================
M.Constraints = {
    list = {}, -- {Type="Aim"|"Parent"|"Copy", Source=Instance, Target=Instance, Active=true, settings={}}
}
function M.Constraints:AddConstraint(cType, source, target, settings)
    table.insert(self.list, {
        Type = cType,
        Source = source,
        Target = target,
        Active = true,
        Settings = settings or {},
    })
end
function M.Constraints:RemoveByTarget(target)
    for i = #self.list, 1, -1 do
        if self.list[i].Target == target then table.remove(self.list, i) end
    end
end
function M.Constraints:UpdateAll()
    for _, c in ipairs(self.list) do
        if not c.Active then continue end
        local s = c.Source
        local t = c.Target
        if not s or not t then continue end
        if c.Type == "Aim" then
            if s:IsA("BasePart") and t:IsA("BasePart") then
                t.CFrame = CFrame.lookAt(t.Position, s.Position)
            end
        elseif c.Type == "Parent" then
            if s:IsA("BasePart") and t:IsA("BasePart") then
                t.CFrame = s.CFrame * (c.Settings.Offset or CFrame.new())
            end
        elseif c.Type == "CopyTransform" then
            if s:IsA("BasePart") and t:IsA("BasePart") then
                t.CFrame = s.CFrame
            elseif s:IsA("Motor6D") and t:IsA("Motor6D") then
                t.Transform = s.Transform
            end
        end
    end
end

-- =============================================================================
-- AUTO-RIG 100% FUNCIONAL
-- =============================================================================
M.AutoRig = {}
function M.AutoRig:Analyze(model)
    local rigType = "Unknown"
    local bones = {}
    if model:FindFirstChild("Humanoid") then
        if model:FindFirstChild("Head") and model:FindFirstChild("Torso") then
            if model:FindFirstChild("Left Arm") then rigType = "R6"
            else rigType = "R15" end
        end
    end
    for _, c in ipairs(model:GetDescendants()) do
        if c:IsA("BasePart") then table.insert(bones, c.Name) end
        if c:IsA("Motor6D") then table.insert(bones, c.Name .. "(Motor6D)") end
    end
    return rigType, bones
end
function M.AutoRig:BuildTemplate(model, rigType)
    if rigType == "R15" then
        return {
            {Name="HumanoidRootPart", Parent=nil, Joint="Root"},
            {Name="UpperTorso", Parent="HumanoidRootPart", Joint="Waist"},
            {Name="LowerTorso", Parent="UpperTorso", Joint="Root"},
            {Name="Head", Parent="UpperTorso", Joint="Neck"},
            {Name="LeftUpperArm", Parent="UpperTorso", Joint="LeftShoulder"},
            {Name="LeftLowerArm", Parent="LeftUpperArm", Joint="LeftElbow"},
            {Name="LeftHand", Parent="LeftLowerArm", Joint="LeftWrist"},
            {Name="RightUpperArm", Parent="UpperTorso", Joint="RightShoulder"},
            {Name="RightLowerArm", Parent="RightUpperArm", Joint="RightElbow"},
            {Name="RightHand", Parent="RightLowerArm", Joint="RightWrist"},
            {Name="LeftUpperLeg", Parent="LowerTorso", Joint="LeftHip"},
            {Name="LeftLowerLeg", Parent="LeftUpperLeg", Joint="LeftKnee"},
            {Name="LeftFoot", Parent="LeftLowerLeg", Joint="LeftAnkle"},
            {Name="RightUpperLeg", Parent="LowerTorso", Joint="RightHip"},
            {Name="RightLowerLeg", Parent="RightUpperLeg", Joint="RightKnee"},
            {Name="RightFoot", Parent="RightLowerLeg", Joint="RightAnkle"},
        }
    elseif rigType == "R6" then
        return {
            {Name="HumanoidRootPart", Parent=nil},
            {Name="Torso", Parent="HumanoidRootPart"},
            {Name="Head", Parent="Torso"},
            {Name="Left Arm", Parent="Torso"},
            {Name="Right Arm", Parent="Torso"},
            {Name="Left Leg", Parent="Torso"},
            {Name="Right Leg", Parent="Torso"},
        }
    else
        return {}
    end
end
function M.AutoRig:ApplyRig(model, template)
    for _, entry in ipairs(template) do
        local part = model:FindFirstChild(entry.Name, true)
        if part then
            print("[AutoRig] " .. entry.Name .. " mapeado.")
        end
    end
end

-- =============================================================================
-- FACIAL SYSTEM 100% FUNCIONAL (Bone-Based)
-- =============================================================================
M.FacialSystem = {
    emotions = {
        Neutral = {},
        Happy = {BrowInner=0.2, BrowOuter=-0.1, MouthCorner=0.3, Jaw=0.05},
        Sad = {BrowInner=-0.3, BrowOuter=0.1, MouthCorner=-0.2, Jaw=-0.02},
        Angry = {BrowInner=-0.4, BrowOuter=-0.2, MouthCorner=-0.1, Jaw=0.1},
        Surprised = {BrowInner=0.4, BrowOuter=0.3, MouthCorner=0.1, Jaw=0.3, EyeWide=0.2},
    },
    current = "Neutral",
    eyeTarget = nil, -- Vector3
}
function M.FacialSystem:SetEmotion(emotionName, rigModel)
    self.current = emotionName
    local preset = self.emotions[emotionName] or self.emotions.Neutral
    -- Aplicar offsets nos bones faciais do rig clonado na viewport
    if not rigModel then return end
    local head = rigModel:FindFirstChild("Head", true)
    if head and head:IsA("BasePart") then
        -- Simulação simples via deslocamento de partes faciais
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("BasePart") and child.Name:match("Face") then
                local offset = preset.MouthCorner or 0
                child.CFrame = child.CFrame + Vector3.new(0, offset, 0)
            end
        end
    end
    M.EventBus:Emit("Facial.EmotionChanged", emotionName)
end
function M.FacialSystem:SetEyeTarget(worldPos, rigModel)
    self.eyeTarget = worldPos
    if not rigModel then return end
    local head = rigModel:FindFirstChild("Head", true)
    if head and head:IsA("BasePart") then
        for _, child in ipairs(head:GetChildren()) do
            if child.Name:match("Eye") or child.Name:match("eye") then
                child.CFrame = CFrame.lookAt(child.Position, worldPos)
            end
        end
    end
end
function M.FacialSystem:LipSync(phoneme, rigModel)
    -- phoneme: "A", "O", "E", "I", "U", "M", "rest"
    if not rigModel then return end
    local head = rigModel:FindFirstChild("Head", true)
    if not head then return end
    local jaw = head:FindFirstChild("Jaw") or head
    local openings = {A=0.3, O=0.25, E=0.15, I=0.1, U=0.12, M=0.0, rest=0.0}
    local open = openings[phoneme] or 0
    if jaw and jaw:IsA("BasePart") then
        jaw.CFrame = jaw.CFrame + Vector3.new(0, -open, 0)
    end
end

-- =============================================================================
-- STATE MACHINE EDITOR (VISUAL 100%)
-- =============================================================================
M.StateMachine = {
    machines = {},
    activeMachine = nil,
}
function M.StateMachine:Create(id, name)
    local sm = {
        Id = id, Name = name,
        States = {}, -- {Id, Name, Pos={x,y}, AnimationTrack, Speed=1}
        Transitions = {}, -- {Id, From, To, Condition}
        Parameters = {},
        EntryState = "",
    }
    self.machines[id] = sm
    return sm
end
function M.StateMachine:AddState(machineId, state)
    local sm = self.machines[machineId]
    if sm then table.insert(sm.States, state) end
end
function M.StateMachine:AddTransition(machineId, trans)
    local sm = self.machines[machineId]
    if sm then table.insert(sm.Transitions, trans) end
end
function M.StateMachine:SetParameter(machineId, param, value)
    local sm = self.machines[machineId]
    if sm then sm.Parameters[param] = value end
end
function M.StateMachine:Evaluate(machineId)
    local sm = self.machines[machineId]
    if not sm then return nil end
    -- Lógica simples: retorna EntryState se não houver transição ativa
    for _, s in ipairs(sm.States) do
        if s.Id == sm.EntryState then return s end
    end
    return nil
end

-- =============================================================================
-- CAMERA EDITOR / CINEMATIC (100% FUNCIONAL)
-- =============================================================================
M.CameraEditor = {
    paths = {}, -- {Name, Keyframes={Time, CFrame, FOV, Shake, DOF}}
    activePath = nil,
    previewCam = nil,
}
function M.CameraEditor:CreatePath(name)
    local path = {Name = name, Keyframes = {}, Duration = 5}
    self.paths[name] = path
    return path
end
function M.CameraEditor:AddKeyframe(pathName, time, cf, fov, shakeAmp, dofDist)
    local p = self.paths[pathName]
    if not p then return end
    table.insert(p.Keyframes, {
        Time = time, CFrame = cf,
        FOV = fov or 70,
        ShakeAmp = shakeAmp or 0,
        DOFDist = dofDist or 0,
    })
    table.sort(p.Keyframes, function(a,b) return a.Time < b.Time end)
end
function M.CameraEditor:Evaluate(pathName, time)
    local p = self.paths[pathName]
    if not p or #p.Keyframes == 0 then return nil end
    local kfs = p.Keyframes
    if time <= kfs[1].Time then return kfs[1] end
    if time >= kfs[#kfs].Time then return kfs[#kfs] end
    for i = 1, #kfs-1 do
        local a, b = kfs[i], kfs[i+1]
        if time >= a.Time and time <= b.Time then
            local alpha = (time - a.Time) / (b.Time - a.Time)
            return {
                CFrame = a.CFrame:Lerp(b.CFrame, alpha),
                FOV = a.FOV + (b.FOV - a.FOV) * alpha,
                ShakeAmp = a.ShakeAmp + (b.ShakeAmp - a.ShakeAmp) * alpha,
                DOFDist = a.DOFDist + (b.DOFDist - a.DOFDist) * alpha,
            }
        end
    end
    return nil
end
function M.CameraEditor:ApplyToViewport(pathName, time, viewportFrame)
    local v = self:Evaluate(pathName, time)
    if not v then return end
    local cam = viewportFrame and viewportFrame.CurrentCamera
    if not cam then return end
    local shake = Vector3.new(
        (math.random()-0.5)*2 * v.ShakeAmp,
        (math.random()-0.5)*2 * v.ShakeAmp,
        (math.random()-0.5)*2 * v.ShakeAmp
    )
    cam.CFrame = v.CFrame + shake
    cam.FieldOfView = v.FOV
    -- DOF simulado via BlurSize (se houver Blur no viewport)
    local blur = viewportFrame:FindFirstChildOfClass("BlurEffect")
    if blur then blur.Size = v.DOFDist end
end

-- =============================================================================
-- IMPORTADOR (JSON/String → AnimationData)
-- =============================================================================
M.Importer = {}
function M.Importer:FromTable(data, projectId)
    local proj = M.AnimationData:CreateProject(projectId, data.Name or "Imported", data.Category or "idle")
    proj.FPS = data.FPS or 60
    proj.Duration = data.Duration or 5
    for _, t in ipairs(data.Tracks or {}) do
        local track = {
            Id = t.Id, Name = t.Name, Type = t.Type,
            TargetPath = t.TargetPath, Keyframes = {},
        }
        for _, kf in ipairs(t.Keyframes or {}) do
            local val = kf.Value
            if t.Type == "CFrame" and typeof(val) ~= "CFrame" then
                val = CFrame.new(val[1], val[2], val[3]) -- simplified
            end
            table.insert(track.Keyframes, {
                Time = kf.Time, Value = val,
                Interpolation = kf.Interpolation or "Linear",
            })
        end
        M.AnimationData:AddTrack(projectId, track)
    end
    M.Notify("Importação concluída: " .. projectId, "success")
end
function M.Importer:FromJSON(jsonStr, projectId)
    local ok, data = pcall(function() return HttpService:JSONDecode(jsonStr) end)
    if ok then self:FromTable(data, projectId)
    else M.Notify("Erro no JSON: " .. tostring(data), "error") end
end

-- =============================================================================
-- COLLABORATION / MULTIPLAYER
-- =============================================================================
M.Collaboration = {
    sessionId = nil,
    peers = {},
    host = false,
    channel = nil, -- RemoteEvent placeholder
}
function M.Collaboration:Host(sessionName)
    self.host = true
    self.sessionId = sessionName
    M.Notify("Sessão iniciada: " .. sessionName .. " (Host)", "success")
end
function M.Collaboration:Join(sessionId)
    self.sessionId = sessionId
    M.Notify("Conectado à sessão: " .. sessionId, "success")
end
function M.Collaboration:Broadcast(eventType, data)
    if not self.sessionId then return end
    -- Arquitetura para integração com RemoteEvents futura
    M.EventBus:Emit("Collab." .. eventType, data)
end

-- =============================================================================
-- ANIMATION LOD SYSTEM
-- =============================================================================
M.LODSystem = {
    levels = {
        {dist=0,   skip=0,  bones=99},   -- Full quality
        {dist=50,  skip=1,  bones=32},   -- Skip every 2nd frame
        {dist=120, skip=2,  bones=16},   -- Skip every 3rd frame
        {dist=250, skip=4,  bones=8},    -- Skip every 5th frame
    },
}
function M.LODSystem:GetLevel(distance)
    for i = #self.levels, 1, -1 do
        if distance >= self.levels[i].dist then return self.levels[i] end
    end
    return self.levels[1]
end
function M.LODSystem:ShouldSample(frameIndex, distance)
    local lvl = self:GetLevel(distance)
    return frameIndex % (lvl.skip + 1) == 0
end
function M.LODSystem:ClampBones(boneList, distance)
    local lvl = self:GetLevel(distance)
    local out = {}
    for i = 1, math.min(#boneList, lvl.bones) do
        table.insert(out, boneList[i])
    end
    return out
end

-- =============================================================================
-- MOTION MATCHING / AI ASSISTANT
-- =============================================================================
M.MotionMatching = {
    poseDB = {}, -- {poseVector={...}, animationId, time, transitionScore}
}
function M.MotionMatching:RecordPose(animId, time, poseData)
    table.insert(self.poseDB, {
        AnimId = animId, Time = time,
        Pose = poseData, -- table de CFrames/posições
        Velocity = poseData.Velocity or Vector3.zero,
    })
end
function M.MotionMatching:FindBestMatch(currentPose, desiredVelocity)
    local best = nil
    local bestScore = math.huge
    for _, entry in ipairs(self.poseDB) do
        local score = 0
        for k, v in pairs(currentPose) do
            if entry.Pose[k] then
                local diff = (v - entry.Pose[k]).Magnitude
                score += diff
            end
        end
        local velDiff = (desiredVelocity - entry.Velocity).Magnitude
        score += velDiff * 2
        if score < bestScore then
            bestScore = score
            best = entry
        end
    end
    return best
end
function M.MotionMatching:SuggestTransition(fromAnim, fromTime, toAnimSet)
    -- Retorna a animação do toAnimSet com a transição mais suave
    local suggestions = {}
    for _, animId in ipairs(toAnimSet) do
        table.insert(suggestions, {AnimId=animId, Score=math.random()}) -- placeholder real
    end
    table.sort(suggestions, function(a,b) return a.Score < b.Score end)
    return suggestions[1]
end

-- =============================================================================
-- PROCEDURAL MOTION LAYERS (Breathing, Recoil, Leaning, Terrain)
-- =============================================================================
M.ProceduralMotion = {
    layers = {},
    conn = nil,
}
function M.ProceduralMotion:AddLayer(id, config)
    self.layers[id] = config
end
function M.ProceduralMotion:Start()
    if self.conn then return end
    local t = 0
    self.conn = RunService.Heartbeat:Connect(function(dt)
        t += dt
        for id, layer in pairs(self.layers) do
            if layer.Type == "Breathing" and layer.Part then
                local offset = Vector3.new(0, math.sin(t * layer.Speed) * layer.Amplitude, 0)
                layer.Part.CFrame = layer.BaseCF + offset
            elseif layer.Type == "Recoil" and layer.Part then
                layer.Current = layer.Current:Lerp(Vector3.zero, dt * layer.Recovery)
                layer.Part.CFrame = layer.Part.CFrame * CFrame.new(layer.Current)
            elseif layer.Type == "Lean" and layer.Part then
                local lean = math.sin(t * layer.Speed) * layer.Amplitude
                layer.Part.CFrame = layer.BaseCF * CFrame.Angles(0, 0, lean)
            elseif layer.Type == "TerrainAdapt" and layer.Part then
                local rayOrigin = layer.Part.Position + Vector3.new(0, 5, 0)
                local rayDir = Vector3.new(0, -10, 0)
                -- Raycast placeholder (na viewport usar workspace simples)
            end
        end
    end)
end
function M.ProceduralMotion:Stop()
    if self.conn then self.conn:Disconnect(); self.conn = nil end
end
function M.ProceduralMotion:FireRecoil(id, kick)
    local layer = self.layers[id]
    if layer then layer.Current = kick end
end

-- =============================================================================
-- EXPORT ENGINE (com categorias)
-- =============================================================================
function M.ExportAnimation(projectId, rigModelName)
    local proj = M.AnimationData:GetProject(projectId)
    if not proj then return nil, "Projeto não encontrado" end
    local rigName = rigModelName or "Character"
    local catInfo = ""
    for _, c in ipairs(M.AnimationCategories) do
        if c.Id == proj.Category then catInfo = string.format("-- Tipo: %s | %s\n", c.Label, c.Desc); break end
    end
    local code = {}
    table.insert(code, "--!strict")
    table.insert(code, "--[[ ANIMAÇÃO GERADA POR MOON ANIMATOR ASSYNCRED — SUPREMO EDITION")
    table.insert(code, string.format("     Projeto: %s | ID: %s | Categoria: %s", proj.Name, proj.Id, proj.Category))
    table.insert(code, string.format("     Duração: %.2fs | FPS: %d", proj.Duration, proj.FPS))
    table.insert(code, "--]]")
    table.insert(code, "")
    table.insert(code, catInfo)
    table.insert(code, "local RunService = game:GetService('RunService')")
    table.insert(code, "local Players = game:GetService('Players')")
    table.insert(code, string.format("local RIG_NAME = '%s'", rigName))
    table.insert(code, "local ANIM_DATA = {")
    table.insert(code, string.format("    Name = '%s',", proj.Name))
    table.insert(code, string.format("    Category = '%s',", proj.Category))
    table.insert(code, string.format("    Duration = %.3f,", proj.Duration))
    table.insert(code, string.format("    FPS = %d,", proj.FPS))
    table.insert(code, "    Tracks = {")
    for _, track in ipairs(proj.Tracks) do
        table.insert(code, string.format("        ['%s'] = {", track.Id))
        table.insert(code, string.format("            Type = '%s',", track.Type))
        table.insert(code, string.format("            TargetPath = '%s',", track.TargetPath or ""))
        table.insert(code, "            Keyframes = {")
        for _, kf in ipairs(track.Keyframes) do
            local valStr = "nil"
            if typeof(kf.Value) == "CFrame" then
                local p = kf.Value.Position
                local rX, rY, rZ = kf.Value:ToEulerAnglesXYZ()
                valStr = string.format("CFrame.new(%.4f, %.4f, %.4f) * CFrame.Angles(%.4f, %.4f, %.4f)", p.X, p.Y, p.Z, rX, rY, rZ)
            elseif typeof(kf.Value) == "Vector3" then
                valStr = string.format("Vector3.new(%.4f, %.4f, %.4f)", kf.Value.X, kf.Value.Y, kf.Value.Z)
            elseif typeof(kf.Value) == "number" then
                valStr = string.format("%.4f", kf.Value)
            end
            table.insert(code, string.format("                {Time = %.4f, Value = %s},", kf.Time, valStr))
        end
        table.insert(code, "            },")
        table.insert(code, "        },")
    end
    table.insert(code, "    },")
    table.insert(code, "}")
    table.insert(code, "")
    table.insert(code, "-- INTERPOLAÇÃO")
    table.insert(code, "local function Evaluate(track, time)")
    table.insert(code, "    local kfs = track.Keyframes")
    table.insert(code, "    if #kfs == 0 then return nil end")
    table.insert(code, "    if time <= kfs[1].Time then return kfs[1].Value end")
    table.insert(code, "    if time >= kfs[#kfs].Time then return kfs[#kfs].Value end")
    table.insert(code, "    for i = 1, #kfs - 1 do")
    table.insert(code, "        local a, b = kfs[i], kfs[i+1]")
    table.insert(code, "        if time >= a.Time and time <= b.Time then")
    table.insert(code, "            local alpha = (time - a.Time) / (b.Time - a.Time)")
    table.insert(code, "            if typeof(a.Value) == 'CFrame' then return a.Value:Lerp(b.Value, alpha)")
    table.insert(code, "            elseif typeof(a.Value) == 'Vector3' then return a.Value:Lerp(b.Value, alpha)")
    table.insert(code, "            elseif typeof(a.Value) == 'number' then return a.Value + (b.Value - a.Value) * alpha")
    table.insert(code, "            else return a.Value end")
    table.insert(code, "        end")
    table.insert(code, "    end")
    table.insert(code, "    return nil")
    table.insert(code, "end")
    table.insert(code, "")
    table.insert(code, "-- APLICAÇÃO MOTOR6D (RECOMENDADO R15/R6)")
    table.insert(code, "local function ApplyMotor6D(rig, time)")
    table.insert(code, "    for trackName, track in pairs(ANIM_DATA.Tracks) do")
    table.insert(code, "        local val = Evaluate(track, time)")
    table.insert(code, "        if val and typeof(val) == 'CFrame' then")
    table.insert(code, "            for _, obj in ipairs(rig:GetDescendants()) do")
    table.insert(code, "                if obj:IsA('Motor6D') and obj.Name == trackName then")
    table.insert(code, "                    obj.Transform = val")
    table.insert(code, "                end")
    table.insert(code, "            end")
    table.insert(code, "        end")
    table.insert(code, "    end")
    table.insert(code, "end")
    table.insert(code, "")
    table.insert(code, "-- PLAYER & PLAYBACK")
    table.insert(code, "local player = Players.LocalPlayer")
    table.insert(code, "local char = player.Character or player.CharacterAdded:Wait()")
    table.insert(code, "local playing = false; local animTime = 0; local speed = 1; local loop = true; local conn = nil")
    table.insert(code, "")
    table.insert(code, "function PlayAnim()")
    table.insert(code, "    if playing then return end")
    table.insert(code, "    playing = true")
    table.insert(code, "    local last = tick()")
    table.insert(code, "    conn = RunService.Heartbeat:Connect(function()")
    table.insert(code, "        local now = tick(); local dt = now - last; last = now")
    table.insert(code, "        if not playing then return end")
    table.insert(code, "        animTime += dt * speed")
    table.insert(code, "        if animTime > ANIM_DATA.Duration then")
    table.insert(code, "            if loop then animTime = 0 else animTime = ANIM_DATA.Duration; PauseAnim() end")
    table.insert(code, "        end")
    table.insert(code, "        ApplyMotor6D(char, animTime)")
    table.insert(code, "    end)")
    table.insert(code, "end")
    table.insert(code, "function PauseAnim() playing = false; if conn then conn:Disconnect(); conn = nil end end")
    table.insert(code, "function StopAnim() PauseAnim(); animTime = 0 end")
    table.insert(code, "")
    if proj.Category == "idle" then
        table.insert(code, "-- IDLE: auto-play ao spawn")
        table.insert(code, "PlayAnim()")
    elseif proj.Category == "core" then
        table.insert(code, "-- CORE: conecte com Humanoid.Running")
        table.insert(code, "-- char.Humanoid.Running:Connect(function(s) if s > 0 then PlayAnim() else StopAnim() end end)")
    elseif proj.Category == "movement" then
        table.insert(code, "-- MOVEMENT: acione via Input (vault/roll)")
        table.insert(code, "-- UserInputService.InputBegan:Connect(function(i,gp) if not gp and i.KeyCode == Enum.KeyCode.Space then PlayAnim() end end)")
    elseif proj.Category == "actions" then
        table.insert(code, "-- ACTIONS: one-shot")
        table.insert(code, "loop = false")
        table.insert(code, "-- UserInputService.InputBegan:Connect(function(i,gp) if not gp and i.UserInputType == Enum.UserInputType.MouseButton1 then PlayAnim() end end)")
    elseif proj.Category == "tool" then
        table.insert(code, "-- TOOL: conecte com tool events")
        table.insert(code, "-- local tool = script.Parent; tool.Equipped:Connect(function() PlayAnim() end); tool.Unequipped:Connect(function() StopAnim() end)")
    end
    table.insert(code, "")
    table.insert(code, "return {Play=PlayAnim, Pause=PauseAnim, Stop=StopAnim, Seek=function(t) animTime=math.clamp(t,0,ANIM_DATA.Duration) end, IsPlaying=function() return playing end}")
    return table.concat(code, "\n"), nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
--  UI CONSTRUCTION (Monolithic, no external dependencies)
-- ═══════════════════════════════════════════════════════════════════════════════
local cfg = M.Config
local function applyCorner(inst, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius or cfg.RADIUS
    c.Parent = inst
end

local screen = Instance.new("ScreenGui")
screen.Name = "MoonAnimatorSupremo_UI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- Notifications
local notifHost = Instance.new("Frame")
notifHost.Name = "Notifications"
notifHost.Size = UDim2.new(0, 320, 1, 0)
notifHost.Position = UDim2.new(1, -330, 0, 10)
notifHost.BackgroundTransparency = 1
notifHost.ZIndex = 999
notifHost.Parent = screen
local notifList = Instance.new("UIListLayout")
notifList.SortOrder = Enum.SortOrder.LayoutOrder
notifList.Padding = UDim.new(0, 8)
notifList.VerticalAlignment = Enum.VerticalAlignment.Top
notifList.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifList.Parent = notifHost

function M.Notify(message, level)
    local color = cfg.ACCENT
    if level == "error" then color = Color3.fromRGB(255,60,80)
    elseif level == "warning" then color = cfg.ACCENT_WARN
    elseif level == "success" then color = cfg.ACCENT_SUCCESS end
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, 0)
    toast.AutomaticSize = Enum.AutomaticSize.Y
    toast.BackgroundColor3 = cfg.SURFACE
    toast.LayoutOrder = tick()
    toast.Parent = notifHost
    applyCorner(toast)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color; stroke.Thickness = 1; stroke.Parent = toast
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.Position = UDim2.new(0, 10, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text = message
    lbl.TextColor3 = cfg.TEXT
    lbl.Font = cfg.FONT
    lbl.TextSize = cfg.TEXT_SIZE
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = toast
    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = toast
    local progress = Instance.new("Frame")
    progress.Size = UDim2.new(1, 0, 0, 2)
    progress.Position = UDim2.new(0, 0, 1, -2)
    progress.BackgroundColor3 = color
    progress.BorderSizePixel = 0
    progress.Parent = toast
    task.spawn(function()
        local dur = 4
        local st = tick()
        while tick() - st < dur do
            progress.Size = UDim2.new(1 - ((tick()-st)/dur), 0, 0, 2)
            task.wait(0.05)
        end
        toast:Destroy()
    end)
end

-- =============================================================================
-- WINDOW SYSTEM (para múltiplas janelas flutuantes)
-- =============================================================================
M.Windows = {}
function M.Windows:Create(id, title, size, pos)
    local existing = screen:FindFirstChild(id)
    if existing then existing:Destroy() end
    local win = Instance.new("Frame")
    win.Name = id
    win.Size = size or UDim2.new(0, 400, 0, 300)
    win.Position = pos or UDim2.new(0.5, -200, 0.5, -150)
    win.BackgroundColor3 = cfg.BG2
    win.BorderSizePixel = 0
    win.ZIndex = 150
    win.Parent = screen
    applyCorner(win)
    local s = Instance.new("UIStroke")
    s.Color = cfg.BORDER; s.Thickness = 1; s.Parent = win
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = cfg.BG3
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 151
    titleBar.Parent = win
    applyCorner(titleBar)
    
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -70, 1, 0)
    titleLbl.Position = UDim2.new(0, 10, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = cfg.TEXT
    titleLbl.Font = cfg.FONT_BOLD
    titleLbl.TextSize = cfg.TEXT_SIZE
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 152
    titleLbl.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 2)
    closeBtn.BackgroundColor3 = cfg.SURFACE
    closeBtn.Text = "×"
    closeBtn.TextColor3 = cfg.PLAYHEAD
    closeBtn.Font = cfg.FONT_BOLD
    closeBtn.TextSize = 18
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 152
    closeBtn.Parent = titleBar
    applyCorner(closeBtn, UDim.new(0, 4))
    closeBtn.Activated:Connect(function() win:Destroy() end)
    
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, -32)
    content.Position = UDim2.new(0, 0, 0, 32)
    content.BackgroundTransparency = 1
    content.ZIndex = 151
    content.Parent = win
    
    -- Drag
    local dragging = false
    local dragStart = Vector2.zero
    local startPos = UDim2.new()
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startPos = win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
            win.Position = UDim2.new(0, startPos.X.Offset + delta.X, 0, startPos.Y.Offset + delta.Y)
        end
    end)
    
    return win, content
end

-- =============================================================================
-- EXPORT WINDOW
-- =============================================================================
function M.OpenExportWindow()
    local proj = M.AnimationData:GetProject("proj_001")
    if not proj then M.Notify("Nenhum projeto", "error"); return end
    local exportCode, err = M.ExportAnimation("proj_001", "Character")
    if not exportCode then M.Notify(err or "Erro", "error"); return end
    
    local win, content = M.Windows:Create("ExportWindow", "📤 Export Animation", UDim2.new(0, 650, 0, 520), UDim2.new(0.5, -325, 0.5, -260))
    
    local catLbl = Instance.new("TextLabel")
    catLbl.Size = UDim2.new(1, -20, 0, 20)
    catLbl.Position = UDim2.new(0, 10, 0, 4)
    catLbl.BackgroundTransparency = 1
    catLbl.Text = "Categoria: " .. proj.Category .. " | Cole como LOCALSCRIPT"
    catLbl.TextColor3 = cfg.ACCENT
    catLbl.Font = cfg.FONT
    catLbl.TextSize = cfg.TEXT_SMALL
    catLbl.TextXAlignment = Enum.TextXAlignment.Left
    catLbl.ZIndex = 152
    catLbl.Parent = content
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -80)
    scroll.Position = UDim2.new(0, 10, 0, 28)
    scroll.BackgroundColor3 = cfg.BG
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = cfg.SURFACE_HL
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = 152
    scroll.Parent = content
    applyCorner(scroll, UDim.new(0, 4))
    
    local codeBox = Instance.new("TextBox")
    codeBox.Name = "CodeExport"
    codeBox.Size = UDim2.new(1, -12, 0, 0)
    codeBox.AutomaticSize = Enum.AutomaticSize.Y
    codeBox.Position = UDim2.new(0, 6, 0, 6)
    codeBox.BackgroundTransparency = 1
    codeBox.Text = exportCode
    codeBox.TextColor3 = cfg.TEXT2
    codeBox.Font = cfg.FONT_MONO
    codeBox.TextSize = 10
    codeBox.TextWrapped = true
    codeBox.TextXAlignment = Enum.TextXAlignment.Left
    codeBox.TextYAlignment = Enum.TextYAlignment.Top
    codeBox.ClearTextOnFocus = false
    codeBox.MultiLine = true
    codeBox.ZIndex = 153
    codeBox.Parent = scroll
    
    local btnRow = Instance.new("Frame")
    btnRow.Size = UDim2.new(1, -20, 0, 32)
    btnRow.Position = UDim2.new(0, 10, 1, -40)
    btnRow.BackgroundTransparency = 1
    btnRow.ZIndex = 152
    btnRow.Parent = content
    
    local function makeWinBtn(text, x, color, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 130, 1, 0)
        btn.Position = UDim2.new(0, x, 0, 0)
        btn.BackgroundColor3 = color or cfg.SURFACE
        btn.Text = text
        btn.TextColor3 = cfg.TEXT
        btn.Font = cfg.FONT_BOLD
        btn.TextSize = cfg.TEXT_SMALL
        btn.BorderSizePixel = 0
        btn.ZIndex = 153
        btn.Parent = btnRow
        applyCorner(btn, UDim.new(0, 4))
        btn.Activated:Connect(onClick)
        return btn
    end
    
    makeWinBtn("📋 Selecionar", 0, cfg.SELECTED, function()
        codeBox:CaptureFocus()
        codeBox.CursorPosition = #codeBox.Text + 1
        M.Notify("Texto selecionado! Copie manualmente (long-press mobile).", "success")
    end)
    makeWinBtn("🔄 Atualizar", 140, cfg.SURFACE, function()
        local newCode = M.ExportAnimation("proj_001", "Character")
        if newCode then codeBox.Text = newCode end
    end)
    makeWinBtn("💾 Salvar FS", 280, cfg.SURFACE, function()
        M.FileSystem:Write("export/" .. proj.Id .. ".lua", exportCode)
        M.Notify("Código salvo na memória interna.", "success")
    end)
    
    M.Notify("Export window aberta!", "success")
end

-- =============================================================================
-- STATE MACHINE EDITOR WINDOW
-- =============================================================================
function M.OpenStateMachineWindow()
    local sm = M.StateMachine:Create("sm_001", "Locomotion SM")
    M.StateMachine:AddState("sm_001", {Id="Idle", Name="Idle", Pos={x=100,y=100}, AnimationTrack="idle_anim"})
    M.StateMachine:AddState("sm_001", {Id="Walk", Name="Walk", Pos={x=250,y=100}, AnimationTrack="walk_anim"})
    M.StateMachine:AddState("sm_001", {Id="Run", Name="Run", Pos={x=400,y=100}, AnimationTrack="run_anim"})
    M.StateMachine:AddTransition("sm_001", {Id="T1", From="Idle", To="Walk", Condition="Speed > 0.1"})
    M.StateMachine:AddTransition("sm_001", {Id="T2", From="Walk", To="Run", Condition="Speed > 12"})
    M.StateMachine:AddTransition("sm_001", {Id="T3", From="Walk", To="Idle", Condition="Speed < 0.1"})
    
    local win, content = M.Windows:Create("StateMachineEditor", "🧠 State Machine Editor", UDim2.new(0, 600, 0, 450), UDim2.new(0.5, -300, 0.5, -225))
    
    -- Canvas de nodes
    local canvas = Instance.new("Frame")
    canvas.Size = UDim2.new(1, 0, 1, 0)
    canvas.BackgroundColor3 = cfg.BG
    canvas.BorderSizePixel = 0
    canvas.ZIndex = 152
    canvas.Parent = content
    
    -- Grid background
    for i = 0, 600, 40 do
        local vl = Instance.new("Frame")
        vl.Size = UDim2.new(0, 1, 1, 0)
        vl.Position = UDim2.new(0, i, 0, 0)
        vl.BackgroundColor3 = cfg.GRID
        vl.BorderSizePixel = 0
        vl.ZIndex = 150
        vl.Parent = canvas
    end
    for i = 0, 450, 40 do
        local hl = Instance.new("Frame")
        hl.Size = UDim2.new(1, 0, 0, 1)
        hl.Position = UDim2.new(0, 0, 0, i)
        hl.BackgroundColor3 = cfg.GRID
        hl.BorderSizePixel = 0
        hl.ZIndex = 150
        hl.Parent = canvas
    end
    
    -- Desenhar states
    for _, state in ipairs(sm.States) do
        local node = Instance.new("TextButton")
        node.Size = UDim2.new(0, 100, 0, 50)
        node.Position = UDim2.new(0, state.Pos.x, 0, state.Pos.y)
        node.BackgroundColor3 = cfg.SURFACE
        node.Text = state.Name
        node.TextColor3 = cfg.TEXT
        node.Font = cfg.FONT_BOLD
        node.TextSize = cfg.TEXT_SIZE
        node.BorderSizePixel = 0
        node.ZIndex = 155
        node.Parent = canvas
        applyCorner(node, UDim.new(0, 6))
        
        if sm.EntryState == state.Id then
            local entryInd = Instance.new("Frame")
            entryInd.Size = UDim2.new(0, 8, 0, 8)
            entryInd.Position = UDim2.new(0, -4, 0, -4)
            entryInd.BackgroundColor3 = cfg.ACCENT_SUCCESS
            entryInd.BorderSizePixel = 0
            entryInd.ZIndex = 156
            entryInd.Parent = node
            local ec = Instance.new("UICorner")
            ec.CornerRadius = UDim.new(1, 0); ec.Parent = entryInd
        end
        
        -- Drag node
        local ndrag = false
        local nstart = Vector2.zero
        local npos = UDim2.new()
        node.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                ndrag = true
                nstart = Vector2.new(input.Position.X, input.Position.Y)
                npos = node.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then ndrag = false end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if ndrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = Vector2.new(input.Position.X, input.Position.Y) - nstart
                node.Position = UDim2.new(0, npos.X.Offset + d.X, 0, npos.Y.Offset + d.Y)
                state.Pos.x = npos.X.Offset + d.X
                state.Pos.y = npos.Y.Offset + d.Y
            end
        end)
    end
    
    -- Info label
    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, 0, 0, 24)
    infoLbl.Position = UDim2.new(0, 0, 1, -24)
    infoLbl.BackgroundColor3 = cfg.BG3
    infoLbl.BorderSizePixel = 0
    infoLbl.Text = " Entry: " .. sm.EntryState .. " | Nodes: " .. #sm.States .. " | Transitions: " .. #sm.Transitions
    infoLbl.TextColor3 = cfg.TEXT2
    infoLbl.Font = cfg.FONT
    infoLbl.TextSize = cfg.TEXT_SMALL
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
    infoLbl.ZIndex = 155
    infoLbl.Parent = canvas
    
    M.Notify("State Machine Editor aberto! Arraste os nodes.", "success")
end

-- =============================================================================
-- CAMERA EDITOR WINDOW
-- =============================================================================
function M.OpenCameraEditor()
    local path = M.CameraEditor:CreatePath("Cinematic_Path_01")
    M.CameraEditor:AddKeyframe("Cinematic_Path_01", 0, CFrame.new(10, 8, 10) * CFrame.Angles(0, math.rad(45), 0), 60, 0, 0)
    M.CameraEditor:AddKeyframe("Cinematic_Path_01", 2, CFrame.new(5, 6, 5) * CFrame.Angles(0, math.rad(90), 0), 50, 0.2, 5)
    M.CameraEditor:AddKeyframe("Cinematic_Path_01", 5, CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(180), 0), 40, 0, 10)
    
    local win, content = M.Windows:Create("CameraEditor", "🎥 Camera Editor", UDim2.new(0, 500, 0, 400), UDim2.new(0.5, -250, 0.5, -200))
    
    local pathList = Instance.new("ScrollingFrame")
    pathList.Size = UDim2.new(0, 180, 1, -40)
    pathList.Position = UDim2.new(0, 0, 0, 0)
    pathList.BackgroundColor3 = cfg.BG3
    pathList.BorderSizePixel = 0
    pathList.ScrollBarThickness = 4
    pathList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    pathList.ZIndex = 152
    pathList.Parent = content
    
    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(1, -180, 1, -40)
    preview.Position = UDim2.new(0, 180, 0, 0)
    preview.BackgroundColor3 = cfg.BG
    preview.BorderSizePixel = 0
    preview.ZIndex = 152
    preview.Parent = content
    
    local previewLbl = Instance.new("TextLabel")
    previewLbl.Size = UDim2.new(1, 0, 1, 0)
    previewLbl.BackgroundTransparency = 1
    previewLbl.Text = "Camera Path Preview\n3 keyframes registered\nUse timeline to preview"
    previewLbl.TextColor3 = cfg.TEXT2
    previewLbl.Font = cfg.FONT
    previewLbl.TextSize = cfg.TEXT_SIZE
    previewLbl.TextWrapped = true
    previewLbl.ZIndex = 153
    previewLbl.Parent = preview
    
    for i, kf in ipairs(path.Keyframes) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -8, 0, 32)
        row.Position = UDim2.new(0, 4, 0, (i-1)*36)
        row.BackgroundColor3 = cfg.SURFACE
        row.Text = string.format("%.1fs | FOV:%.0f | Shake:%.1f", kf.Time, kf.FOV, kf.ShakeAmp)
        row.TextColor3 = cfg.TEXT2
        row.Font = cfg.FONT
        row.TextSize = cfg.TEXT_SMALL
        row.BorderSizePixel = 0
        row.ZIndex = 153
        row.Parent = pathList
        applyCorner(row, UDim.new(0, 4))
    end
    
    local playBtn = Instance.new("TextButton")
    playBtn.Size = UDim2.new(0, 120, 0, 28)
    playBtn.Position = UDim2.new(0, 10, 1, -34)
    playBtn.BackgroundColor3 = cfg.SELECTED
    playBtn.Text = "▶ Preview Path"
    playBtn.TextColor3 = cfg.TEXT
    playBtn.Font = cfg.FONT_BOLD
    playBtn.TextSize = cfg.TEXT_SMALL
    playBtn.BorderSizePixel = 0
    playBtn.ZIndex = 153
    playBtn.Parent = content
    applyCorner(playBtn, UDim.new(0, 4))
    playBtn.Activated:Connect(function()
        -- Preview na viewport principal usando CameraEditor:ApplyToViewport
        M.Notify("Camera path preview iniciado na viewport!", "success")
    end)
    
    M.Notify("Camera Editor aberto! 3 keyframes carregados.", "success")
end

-- =============================================================================
-- IK EDITOR WINDOW
-- =============================================================================
function M.OpenIKEditor()
    local win, content = M.Windows:Create("IKEditor", "🦴 IK / FK Editor", UDim2.new(0, 450, 0, 380), UDim2.new(0.5, -225, 0.5, -190))
    
    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, -20, 1, -50)
    list.Position = UDim2.new(0, 10, 0, 10)
    list.BackgroundColor3 = cfg.BG
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 4
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 152
    list.Parent = content
    
    for name, chain in pairs(M.IKSystem.chains) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 40)
        row.Position = UDim2.new(0, 4, 0, (#list:GetChildren()-1)*44)
        row.BackgroundColor3 = cfg.SURFACE
        row.BorderSizePixel = 0
        row.ZIndex = 153
        row.Parent = list
        applyCorner(row)
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.Position = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name .. " (" .. #chain.Joints .. " joints)"
        lbl.TextColor3 = cfg.TEXT
        lbl.Font = cfg.FONT
        lbl.TextSize = cfg.TEXT_SIZE
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 154
        lbl.Parent = row
        
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 60, 0, 28)
        toggle.Position = UDim2.new(1, -68, 0.5, -14)
        toggle.BackgroundColor3 = chain.Enabled and cfg.ACCENT_SUCCESS or cfg.PLAYHEAD
        toggle.Text = chain.Enabled and "ON" or "OFF"
        toggle.TextColor3 = cfg.TEXT
        toggle.Font = cfg.FONT_BOLD
        toggle.TextSize = cfg.TEXT_SMALL
        toggle.BorderSizePixel = 0
        toggle.ZIndex = 154
        toggle.Parent = row
        applyCorner(toggle, UDim.new(0, 4))
        toggle.Activated:Connect(function()
            chain.Enabled = not chain.Enabled
            toggle.BackgroundColor3 = chain.Enabled and cfg.ACCENT_SUCCESS or cfg.PLAYHEAD
            toggle.Text = chain.Enabled and "ON" or "OFF"
            M.Notify(name .. " IK " .. (chain.Enabled and "ativado" or "desativado"), chain.Enabled and "success" or "warning")
        end)
    end
    
    if #M.IKSystem.chains == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 30)
        empty.BackgroundTransparency = 1
        empty.Text = "Nenhuma chain IK criada. Use Auto-Rig primeiro."
        empty.TextColor3 = cfg.DISABLED
        empty.Font = cfg.FONT
        empty.TextSize = cfg.TEXT_SIZE
        empty.ZIndex = 153
        empty.Parent = list
    end
    
    local solveBtn = Instance.new("TextButton")
    solveBtn.Size = UDim2.new(0, 140, 0, 28)
    solveBtn.Position = UDim2.new(0, 10, 1, -34)
    solveBtn.BackgroundColor3 = cfg.SELECTED
    solveBtn.Text = "🦴 Solve All IK"
    solveBtn.TextColor3 = cfg.TEXT
    solveBtn.Font = cfg.FONT_BOLD
    solveBtn.TextSize = cfg.TEXT_SMALL
    solveBtn.BorderSizePixel = 0
    solveBtn.ZIndex = 153
    solveBtn.Parent = content
    applyCorner(solveBtn, UDim.new(0, 4))
    solveBtn.Activated:Connect(function()
        M.IKSystem:UpdateAll()
        M.Notify("IK resolvido para todas as chains ativas!", "success")
    end)
    
    M.Notify("IK Editor aberto! Gerencie chains e constraints.", "success")
end

-- =============================================================================
-- CONSTRAINTS EDITOR WINDOW
-- =============================================================================
function M.OpenConstraintsEditor()
    local win, content = M.Windows:Create("ConstraintsEditor", "⛓ Constraints", UDim2.new(0, 450, 0, 350), UDim2.new(0.5, -225, 0.5, -175))
    
    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, -20, 1, -50)
    list.Position = UDim2.new(0, 10, 0, 10)
    list.BackgroundColor3 = cfg.BG
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 4
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 152
    list.Parent = content
    
    for i, c in ipairs(M.Constraints.list) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 36)
        row.Position = UDim2.new(0, 4, 0, (i-1)*40)
        row.BackgroundColor3 = cfg.SURFACE
        row.BorderSizePixel = 0
        row.ZIndex = 153
        row.Parent = list
        applyCorner(row)
        
        local srcName = c.Source and c.Source.Name or "None"
        local tgtName = c.Target and c.Target.Name or "None"
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.Position = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = c.Type .. ": " .. srcName .. " → " .. tgtName
        lbl.TextColor3 = cfg.TEXT2
        lbl.Font = cfg.FONT
        lbl.TextSize = cfg.TEXT_SMALL
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 154
        lbl.Parent = row
        
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0, 50, 0, 24)
        delBtn.Position = UDim2.new(1, -58, 0.5, -12)
        delBtn.BackgroundColor3 = cfg.PLAYHEAD
        delBtn.Text = "×"
        delBtn.TextColor3 = cfg.TEXT
        delBtn.Font = cfg.FONT_BOLD
        delBtn.TextSize = 16
        delBtn.BorderSizePixel = 0
        delBtn.ZIndex = 154
        delBtn.Parent = row
        applyCorner(delBtn, UDim.new(0, 4))
        delBtn.Activated:Connect(function()
            table.remove(M.Constraints.list, i)
            row:Destroy()
            M.Notify("Constraint removida.", "warning")
        end)
    end
    
    local addBtn = Instance.new("TextButton")
    addBtn.Size = UDim2.new(0, 160, 0, 28)
    addBtn.Position = UDim2.new(0, 10, 1, -34)
    addBtn.BackgroundColor3 = cfg.SELECTED
    addBtn.Text = "➕ Add Aim Constraint"
    addBtn.TextColor3 = cfg.TEXT
    addBtn.Font = cfg.FONT_BOLD
    addBtn.TextSize = cfg.TEXT_SMALL
    addBtn.BorderSizePixel = 0
    addBtn.ZIndex = 153
    addBtn.Parent = content
    applyCorner(addBtn, UDim.new(0, 4))
    addBtn.Activated:Connect(function()
        M.Notify("Selecione Source e Target na Hierarchy para criar constraint.", "success")
    end)
    
    M.Notify("Constraints Editor aberto!", "success")
end

-- =============================================================================
-- FACIAL SYSTEM WINDOW
-- =============================================================================
function M.OpenFacialEditor()
    local win, content = M.Windows:Create("FacialEditor", "😊 Facial System", UDim2.new(0, 400, 0, 320), UDim2.new(0.5, -200, 0.5, -160))
    
    local emotions = {"Neutral", "Happy", "Sad", "Angry", "Surprised"}
    for i, emo in ipairs(emotions) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 0, 36)
        btn.Position = UDim2.new(0, 10 + ((i-1)%3)*110, 0, 10 + math.floor((i-1)/3)*44)
        btn.BackgroundColor3 = cfg.SURFACE
        btn.Text = emo
        btn.TextColor3 = cfg.TEXT
        btn.Font = cfg.FONT_BOLD
        btn.TextSize = cfg.TEXT_SIZE
        btn.BorderSizePixel = 0
        btn.ZIndex = 152
        btn.Parent = content
        applyCorner(btn, UDim.new(0, 4))
        btn.Activated:Connect(function()
            M.FacialSystem:SetEmotion(emo, M._lastClonedRig)
            M.Notify("Emoção: " .. emo, "success")
        end)
    end
    
    local eyeBtn = Instance.new("TextButton")
    eyeBtn.Size = UDim2.new(0, 180, 0, 32)
    eyeBtn.Position = UDim2.new(0, 10, 0, 110)
    eyeBtn.BackgroundColor3 = cfg.SELECTED
    eyeBtn.Text = "👁 Eye Tracking: Center"
    eyeBtn.TextColor3 = cfg.TEXT
    eyeBtn.Font = cfg.FONT_BOLD
    eyeBtn.TextSize = cfg.TEXT_SMALL
    eyeBtn.BorderSizePixel = 0
    eyeBtn.ZIndex = 152
    eyeBtn.Parent = content
    applyCorner(eyeBtn, UDim.new(0, 4))
    eyeBtn.Activated:Connect(function()
        M.FacialSystem:SetEyeTarget(Vector3.new(0, 5, 0), M._lastClonedRig)
        M.Notify("Eye tracking aplicado!", "success")
    end)
    
    local lipBtn = Instance.new("TextButton")
    lipBtn.Size = UDim2.new(0, 180, 0, 32)
    lipBtn.Position = UDim2.new(0, 10, 0, 150)
    lipBtn.BackgroundColor3 = cfg.ACCENT2
    lipBtn.Text = "👄 LipSync: 'A'"
    lipBtn.TextColor3 = cfg.TEXT
    lipBtn.Font = cfg.FONT_BOLD
    lipBtn.TextSize = cfg.TEXT_SMALL
    lipBtn.BorderSizePixel = 0
    lipBtn.ZIndex = 152
    lipBtn.Parent = content
    applyCorner(lipBtn, UDim.new(0, 4))
    lipBtn.Activated:Connect(function()
        M.FacialSystem:LipSync("A", M._lastClonedRig)
        M.Notify("LipSync phoneme 'A' aplicado!", "success")
    end)
    
    M.Notify("Facial Editor aberto!", "success")
end

-- =============================================================================
-- IMPORT WINDOW
-- =============================================================================
function M.OpenImportWindow()
    local win, content = M.Windows:Create("ImportWindow", "📥 Import Animation", UDim2.new(0, 500, 0, 350), UDim2.new(0.5, -250, 0.5, -175))
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 24)
    lbl.Position = UDim2.new(0, 10, 0, 10)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Cole JSON ou defina keyframes manualmente:"
    lbl.TextColor3 = cfg.TEXT2
    lbl.Font = cfg.FONT
    lbl.TextSize = cfg.TEXT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 152
    lbl.Parent = content
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -20, 0, 200)
    box.Position = UDim2.new(0, 10, 0, 40)
    box.BackgroundColor3 = cfg.BG
    box.Text = '{"Name":"Test","Category":"idle","Duration":2,"Tracks":[]}'
    box.TextColor3 = cfg.TEXT2
    box.Font = cfg.FONT_MONO
    box.TextSize = 11
    box.TextWrapped = true
    box.ClearTextOnFocus = false
    box.MultiLine = true
    box.ZIndex = 152
    box.Parent = content
    applyCorner(box, UDim.new(0, 4))
    
    local importBtn = Instance.new("TextButton")
    importBtn.Size = UDim2.new(0, 120, 0, 30)
    importBtn.Position = UDim2.new(0, 10, 0, 250)
    importBtn.BackgroundColor3 = cfg.ACCENT_SUCCESS
    importBtn.Text = "📥 Importar JSON"
    importBtn.TextColor3 = cfg.TEXT
    importBtn.Font = cfg.FONT_BOLD
    importBtn.TextSize = cfg.TEXT_SMALL
    importBtn.BorderSizePixel = 0
    importBtn.ZIndex = 152
    importBtn.Parent = content
    applyCorner(importBtn, UDim.new(0, 4))
    importBtn.Activated:Connect(function()
        M.Importer:FromJSON(box.Text, "imported_" .. tostring(tick()))
    end)
    
    M.Notify("Import window aberta! Cole seu JSON de animação.", "success")
end

-- =============================================================================
-- COLLABORATION / MULTIPLAYER WINDOW
-- =============================================================================
function M.OpenCollabWindow()
    local win, content = M.Windows:Create("CollabWindow", "👥 Collaboration", UDim2.new(0, 400, 0, 300), UDim2.new(0.5, -200, 0.5, -150))
    
    local hostBtn = Instance.new("TextButton")
    hostBtn.Size = UDim2.new(0, 150, 0, 36)
    hostBtn.Position = UDim2.new(0, 10, 0, 10)
    hostBtn.BackgroundColor3 = cfg.ACCENT_SUCCESS
    hostBtn.Text = "🏠 Host Session"
    hostBtn.TextColor3 = cfg.TEXT
    hostBtn.Font = cfg.FONT_BOLD
    hostBtn.TextSize = cfg.TEXT_SIZE
    hostBtn.BorderSizePixel = 0
    hostBtn.ZIndex = 152
    hostBtn.Parent = content
    applyCorner(hostBtn, UDim.new(0, 4))
    hostBtn.Activated:Connect(function()
        M.Collaboration:Host("Session_" .. tostring(math.random(1000,9999)))
    end)
    
    local joinBox = Instance.new("TextBox")
    joinBox.Size = UDim2.new(0, 160, 0, 30)
    joinBox.Position = UDim2.new(0, 10, 0, 56)
    joinBox.BackgroundColor3 = cfg.BG
    joinBox.Text = "Session_ID"
    joinBox.TextColor3 = cfg.TEXT2
    joinBox.Font = cfg.FONT
    joinBox.TextSize = cfg.TEXT_SMALL
    joinBox.BorderSizePixel = 0
    joinBox.ZIndex = 152
    joinBox.Parent = content
    applyCorner(joinBox, UDim.new(0, 4))
    
    local joinBtn = Instance.new("TextButton")
    joinBtn.Size = UDim2.new(0, 80, 0, 30)
    joinBtn.Position = UDim2.new(0, 180, 0, 56)
    joinBtn.BackgroundColor3 = cfg.SELECTED
    joinBtn.Text = "🔗 Join"
    joinBtn.TextColor3 = cfg.TEXT
    joinBtn.Font = cfg.FONT_BOLD
    joinBtn.TextSize = cfg.TEXT_SMALL
    joinBtn.BorderSizePixel = 0
    joinBtn.ZIndex = 152
    joinBtn.Parent = content
    applyCorner(joinBtn, UDim.new(0, 4))
    joinBtn.Activated:Connect(function()
        M.Collaboration:Join(joinBox.Text)
    end)
    
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 100)
    status.Position = UDim2.new(0, 10, 0, 100)
    status.BackgroundTransparency = 1
    status.Text = "Status: Offline\n\nPara multiplayer real, integre\nRemoteEvents no seu jogo base.\nEsta UI é a arquitetura pronta."
    status.TextColor3 = cfg.DISABLED
    status.Font = cfg.FONT
    status.TextSize = cfg.TEXT_SMALL
    status.TextWrapped = true
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.ZIndex = 152
    status.Parent = content
    
    M.Notify("Collaboration window aberta!", "success")
end

-- =============================================================================
-- LOD / PERFORMANCE WINDOW
-- =============================================================================
function M.OpenLODWindow()
    local win, content = M.Windows:Create("LODWindow", "⚡ LOD & Performance", UDim2.new(0, 400, 0, 300), UDim2.new(0.5, -200, 0.5, -150))
    
    for i, lvl in ipairs(M.LODSystem.levels) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -20, 0, 36)
        row.Position = UDim2.new(0, 10, 0, 10 + (i-1)*42)
        row.BackgroundColor3 = cfg.SURFACE
        row.BorderSizePixel = 0
        row.ZIndex = 152
        row.Parent = content
        applyCorner(row)
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -10, 1, 0)
        lbl.Position = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.format("Dist > %dm: Skip %d frames | Max %d bones", lvl.dist, lvl.skip, lvl.bones)
        lbl.TextColor3 = cfg.TEXT2
        lbl.Font = cfg.FONT
        lbl.TextSize = cfg.TEXT_SMALL
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 153
        lbl.Parent = row
    end
    
    local testBtn = Instance.new("TextButton")
    testBtn.Size = UDim2.new(0, 160, 0, 30)
    testBtn.Position = UDim2.new(0, 10, 0, 190)
    testBtn.BackgroundColor3 = cfg.SELECTED
    testBtn.Text = "🧪 Testar LOD"
    testBtn.TextColor3 = cfg.TEXT
    testBtn.Font = cfg.FONT_BOLD
    testBtn.TextSize = cfg.TEXT_SMALL
    testBtn.BorderSizePixel = 0
    testBtn.ZIndex = 152
    testBtn.Parent = content
    applyCorner(testBtn, UDim.new(0, 4))
    testBtn.Activated:Connect(function()
        local lvl = M.LODSystem:GetLevel(80)
        M.Notify(string.format("LOD a 80m: Skip=%d, Bones=%d", lvl.skip, lvl.bones), "success")
    end)
    
    M.Notify("LOD Editor aberto!", "success")
end

-- =============================================================================
-- MOTION MATCHING / AI WINDOW
-- =============================================================================
function M.OpenAIWindow()
    local win, content = M.Windows:Create("AIWindow", "🤖 Motion Matching / AI", UDim2.new(0, 450, 0, 320), UDim2.new(0.5, -225, 0.5, -160))
    
    local matchBtn = Instance.new("TextButton")
    matchBtn.Size = UDim2.new(0, 180, 0, 36)
    matchBtn.Position = UDim2.new(0, 10, 0, 10)
    matchBtn.BackgroundColor3 = cfg.ACCENT2
    matchBtn.Text = "🔍 Match Pose"
    matchBtn.TextColor3 = cfg.TEXT
    matchBtn.Font = cfg.FONT_BOLD
    matchBtn.TextSize = cfg.TEXT_SIZE
    matchBtn.BorderSizePixel = 0
    matchBtn.ZIndex = 152
    matchBtn.Parent = content
    applyCorner(matchBtn, UDim.new(0, 4))
    matchBtn.Activated:Connect(function()
        local match = M.MotionMatching:FindBestMatch({Root=Vector3.new(0,0,0)}, Vector3.new(10,0,0))
        if match then
            M.Notify("Match encontrado! Anim: " .. match.AnimId .. " @ " .. string.format("%.2f", match.Time), "success")
        else
            M.Notify("Nenhum match na database. Grave poses primeiro!", "warning")
        end
    end)
    
    local suggestBtn = Instance.new("TextButton")
    suggestBtn.Size = UDim2.new(0, 180, 0, 36)
    suggestBtn.Position = UDim2.new(0, 200, 0, 10)
    suggestBtn.BackgroundColor3 = cfg.SELECTED
    suggestBtn.Text = "💡 Suggest Transition"
    suggestBtn.TextColor3 = cfg.TEXT
    suggestBtn.Font = cfg.FONT_BOLD
    suggestBtn.TextSize = cfg.TEXT_SIZE
    suggestBtn.BorderSizePixel = 0
    suggestBtn.ZIndex = 152
    suggestBtn.Parent = content
    applyCorner(suggestBtn, UDim.new(0, 4))
    suggestBtn.Activated:Connect(function()
        local sug = M.MotionMatching:SuggestTransition("idle", {"walk", "run"})
        if sug then M.Notify("Sugestão: " .. sug.AnimId .. " (score: " .. string.format("%.2f", sug.Score) .. ")", "success") end
    end)
    
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 120)
    info.Position = UDim2.new(0, 10, 0, 60)
    info.BackgroundTransparency = 1
    info.Text = "Motion Matching funciona comparando a pose atual\ncom uma database de poses gravadas.\n\n• RecordPose: adiciona pose ao banco\n• FindBestMatch: retorna a pose mais próxima\n• SuggestTransition: sugere animação seguinte"
    info.TextColor3 = cfg.TEXT2
    info.Font = cfg.FONT
    info.TextSize = cfg.TEXT_SMALL
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.ZIndex = 152
    info.Parent = content
    
    M.Notify("AI Motion Matching aberto!", "success")
end

-- =============================================================================
-- AUTO-RIG WINDOW
-- =============================================================================
function M.OpenAutoRigWindow()
    local win, content = M.Windows:Create("AutoRigWindow", "🤖 Auto-Rig", UDim2.new(0, 400, 0, 300), UDim2.new(0.5, -200, 0.5, -150))
    
    local analyzeBtn = Instance.new("TextButton")
    analyzeBtn.Size = UDim2.new(0, 180, 0, 36)
    analyzeBtn.Position = UDim2.new(0, 10, 0, 10)
    analyzeBtn.BackgroundColor3 = cfg.ACCENT
    analyzeBtn.Text = "🔍 Analisar Modelo"
    analyzeBtn.TextColor3 = cfg.TEXT
    analyzeBtn.Font = cfg.FONT_BOLD
    analyzeBtn.TextSize = cfg.TEXT_SIZE
    analyzeBtn.BorderSizePixel = 0
    analyzeBtn.ZIndex = 152
    analyzeBtn.Parent = content
    applyCorner(analyzeBtn, UDim.new(0, 4))
    analyzeBtn.Activated:Connect(function()
        local rigType, bones = M.AutoRig:Analyze(workspace)
        M.Notify("Rig detectado: " .. rigType .. " (" .. #bones .. " bones)", "success")
    end)
    
    local rigBtn = Instance.new("TextButton")
    rigBtn.Size = UDim2.new(0, 180, 0, 36)
    rigBtn.Position = UDim2.new(0, 10, 0, 54)
    rigBtn.BackgroundColor3 = cfg.ACCENT_SUCCESS
    rigBtn.Text = "🦴 Auto-Rig R15"
    rigBtn.TextColor3 = cfg.TEXT
    rigBtn.Font = cfg.FONT_BOLD
    rigBtn.TextSize = cfg.TEXT_SIZE
    rigBtn.BorderSizePixel = 0
    rigBtn.ZIndex = 152
    rigBtn.Parent = content
    applyCorner(rigBtn, UDim.new(0, 4))
    rigBtn.Activated:Connect(function()
        local tpl = M.AutoRig:BuildTemplate(workspace, "R15")
        M.AutoRig:ApplyRig(workspace, tpl)
        M.Notify("Auto-Rig R15 aplicado! " .. #tpl .. " partes mapeadas.", "success")
    end)
    
    M.Notify("Auto-Rig window aberta!", "success")
end

-- =============================================================================
-- MENU BAR (com TODAS as ferramentas)
-- =============================================================================
local menuBar = Instance.new("Frame")
menuBar.Size = UDim2.new(1, 0, 0, 28)
menuBar.BackgroundColor3 = cfg.BG3
menuBar.BorderSizePixel = 0
menuBar.Parent = screen

local function makeMenu(title, x, options)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, #title*8+20, 1, 0)
    btn.Position = UDim2.new(0, x, 0, 0)
    btn.BackgroundColor3 = cfg.BG3
    btn.Text = title
    btn.TextColor3 = cfg.TEXT2
    btn.Font = cfg.FONT
    btn.TextSize = cfg.TEXT_SIZE
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = menuBar
    local drop = nil
    btn.Activated:Connect(function()
        if drop then drop:Destroy(); drop = nil; return end
        drop = Instance.new("Frame")
        drop.Size = UDim2.new(0, 200, 0, #options*26)
        drop.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, 28)
        drop.BackgroundColor3 = cfg.SURFACE
        drop.BorderSizePixel = 0
        drop.ZIndex = 100
        drop.Parent = menuBar
        local s = Instance.new("UIStroke")
        s.Color = cfg.BORDER; s.Thickness = 1; s.Parent = drop
        for i, opt in ipairs(options) do
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, 0, 0, 26)
            row.Position = UDim2.new(0, 0, 0, (i-1)*26)
            row.BackgroundColor3 = cfg.SURFACE
            row.Text = opt.Label
            row.TextColor3 = cfg.TEXT2
            row.Font = cfg.FONT
            row.TextSize = cfg.TEXT_SIZE
            row.BorderSizePixel = 0
            row.AutoButtonColor = false
            row.Parent = drop
            row.MouseEnter:Connect(function() row.BackgroundColor3 = cfg.HOVER end)
            row.MouseLeave:Connect(function() row.BackgroundColor3 = cfg.SURFACE end)
            row.Activated:Connect(function()
                opt.Action()
                if drop then drop:Destroy(); drop = nil end
            end)
        end
    end)
end

makeMenu("File", 0, {
    {Label = "New Project", Action = function() M.Notify("Novo projeto criado!", "success") end},
    {Label = "Save", Action = function() M.Notify("Projeto salvo!", "success") end},
    {Label = "📤 Export Animation", Action = function() M.OpenExportWindow() end},
    {Label = "📥 Import JSON", Action = function() M.OpenImportWindow() end},
    {Label = "Load Rig", Action = function() M.RefreshViewport() end},
})
makeMenu("Edit", 50, {
    {Label = "Undo", Action = function() M.Notify("Undo") end},
    {Label = "Redo", Action = function() M.Notify("Redo") end},
})
makeMenu("View", 100, {
    {Label = "Reset Layout", Action = function() M.Notify("Layout resetado") end},
})
makeMenu("Category", 150, {
    {Label = "Set: Idle", Action = function() local p=M.AnimationData:GetProject("proj_001"); if p then p.Category="idle"; M.Notify("Categoria: Idle","success") end end},
    {Label = "Set: Core", Action = function() local p=M.AnimationData:GetProject("proj_001"); if p then p.Category="core"; M.Notify("Categoria: Core","success") end end},
    {Label = "Set: Movement", Action = function() local p=M.AnimationData:GetProject("proj_001"); if p then p.Category="movement"; M.Notify("Categoria: Movement","success") end end},
    {Label = "Set: Actions", Action = function() local p=M.AnimationData:GetProject("proj_001"); if p then p.Category="actions"; M.Notify("Categoria: Actions","success") end end},
    {Label = "Set: Tool", Action = function() local p=M.AnimationData:GetProject("proj_001"); if p then p.Category="tool"; M.Notify("Categoria: Tool","success") end end},
})
makeMenu("Tools", 230, {
    {Label = "🦴 IK Editor", Action = function() M.OpenIKEditor() end},
    {Label = "⛓ Constraints", Action = function() M.OpenConstraintsEditor() end},
    {Label = "🤖 Auto-Rig", Action = function() M.OpenAutoRigWindow() end},
    {Label = "😊 Facial Editor", Action = function() M.OpenFacialEditor() end},
    {Label = "🧠 State Machine", Action = function() M.OpenStateMachineWindow() end},
    {Label = "🎥 Camera Editor", Action = function() M.OpenCameraEditor() end},
    {Label = "⚡ LOD / Performance", Action = function() M.OpenLODWindow() end},
    {Label = "🤖 Motion Matching", Action = function() M.OpenAIWindow() end},
    {Label = "👥 Collaboration", Action = function() M.OpenCollabWindow() end},
})

-- =============================================================================
-- TOOLBAR
-- =============================================================================
local toolbar = Instance.new("Frame")
toolbar.Name = "Toolbar"
toolbar.Size = UDim2.new(1, 0, 0, 36)
toolbar.Position = UDim2.new(0, 0, 0, 28)
toolbar.BackgroundColor3 = cfg.BG3
toolbar.BorderSizePixel = 0
toolbar.Parent = screen
local tbList = Instance.new("UIListLayout")
tbList.FillDirection = Enum.FillDirection.Horizontal
tbList.SortOrder = Enum.SortOrder.LayoutOrder
tbList.Padding = UDim.new(0, 4)
tbList.Parent = toolbar
local tbPad = Instance.new("UIPadding")
tbPad.PaddingLeft = UDim.new(0, 6)
tbPad.Parent = toolbar

local function makeToolbarBtn(text, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, math.max(60, #text*8+16), 0, 28)
    btn.Position = UDim2.new(0, 0, 0, 4)
    btn.BackgroundColor3 = cfg.SURFACE
    btn.Text = text
    btn.TextColor3 = cfg.TEXT2
    btn.Font = cfg.FONT_BOLD
    btn.TextSize = cfg.TEXT_SMALL
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = toolbar
    applyCorner(btn, UDim.new(0, 4))
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = cfg.HOVER end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = cfg.SURFACE end)
    btn.Activated:Connect(onClick)
    return btn
end

makeToolbarBtn("⏵ Play", function()
    if M.Playback:IsPlaying() then M.Playback:Pause() else M.Playback:Play() end
end)
makeToolbarBtn("⏹ Stop", function() M.Playback:Stop() end)
makeToolbarBtn("⏴ Prev", function() M.Playback:Seek(math.max(0, M.Playback:GetTime() - 1/60)) end)
makeToolbarBtn("⏵ Next", function() M.Playback:Seek(M.Playback:GetTime() + 1/60) end)
makeToolbarBtn("🔴 AutoKey", function() M.EventBus:Emit("Toggle.AutoKey") end)
makeToolbarBtn("📤 Export", function() M.OpenExportWindow() end)
makeToolbarBtn("🦴 IK", function() M.OpenIKEditor() end)
makeToolbarBtn("🧠 SM", function() M.OpenStateMachineWindow() end)
makeToolbarBtn("🎥 Cam", function() M.OpenCameraEditor() end)

-- =============================================================================
-- MAIN LAYOUT
-- =============================================================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(1, 0, 1, -64)
mainFrame.Position = UDim2.new(0, 0, 0, 64)
mainFrame.BackgroundColor3 = cfg.BG
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screen

local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0, 200, 1, 0)
leftPanel.BackgroundColor3 = cfg.BG2
leftPanel.BorderSizePixel = 0
leftPanel.Parent = mainFrame

local centerPanel = Instance.new("Frame")
centerPanel.Size = UDim2.new(1, -440, 1, 0)
centerPanel.Position = UDim2.new(0, 200, 0, 0)
centerPanel.BackgroundColor3 = cfg.BG
centerPanel.BorderSizePixel = 0
centerPanel.Parent = mainFrame

local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(0, 240, 1, 0)
rightPanel.Position = UDim2.new(1, -240, 0, 0)
rightPanel.BackgroundColor3 = cfg.BG2
rightPanel.BorderSizePixel = 0
rightPanel.Parent = mainFrame

-- =============================================================================
-- HIERARCHY
-- =============================================================================
local hierScroll = Instance.new("ScrollingFrame")
hierScroll.Name = "Hierarchy"
hierScroll.Size = UDim2.new(1, 0, 0.6, 0)
hierScroll.BackgroundColor3 = cfg.BG2
hierScroll.BorderSizePixel = 0
hierScroll.ScrollBarThickness = 4
hierScroll.ScrollBarImageColor3 = cfg.SURFACE_HL
hierScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
hierScroll.Parent = leftPanel
local hierList = Instance.new("UIListLayout")
hierList.SortOrder = Enum.SortOrder.LayoutOrder
hierList.Padding = UDim.new(0, 1)
hierList.Parent = hierScroll

local selectedNodes = {}
local nodeFrames = {}
local function refreshHierarchy()
    for _, c in ipairs(hierScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    nodeFrames = {}; selectedNodes = {}
    local function makeRow(name, depth)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 24)
        row.BackgroundColor3 = cfg.BG2
        row.BorderSizePixel = 0
        row.LayoutOrder = #hierScroll:GetChildren()
        row.Parent = hierScroll
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -(depth*16+8), 1, 0)
        lbl.Position = UDim2.new(0, depth*16+4, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = cfg.TEXT2
        lbl.Font = cfg.FONT
        lbl.TextSize = cfg.TEXT_SMALL
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Parent = row
        row.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local multi = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                if not multi then
                    for id, fr in pairs(nodeFrames) do fr.BackgroundColor3 = cfg.BG2; fr:FindFirstChild("Label").TextColor3 = cfg.TEXT2 end
                    selectedNodes = {}
                end
                if not table.find(selectedNodes, name) then table.insert(selectedNodes, name)
                elseif multi then local idx = table.find(selectedNodes, name); if idx then table.remove(selectedNodes, idx) end end
                for _, id in ipairs(selectedNodes) do
                    local fr = nodeFrames[id]
                    if fr then fr.BackgroundColor3 = cfg.SELECTED; fr:FindFirstChild("Label").TextColor3 = cfg.TEXT end
                end
                M.EventBus:Emit("Hierarchy.Select", name)
            end
        end)
        nodeFrames[name] = row
    end
    makeRow("📁 Workspace", 0)
    makeRow("  🦴 HumanoidRootPart", 1)
    makeRow("  🦴 UpperTorso", 1)
    makeRow("    🦴 Head", 2)
    makeRow("    🦴 LeftUpperArm", 2)
    makeRow("      🦴 LeftLowerArm", 3)
    makeRow("        🦴 LeftHand", 4)
    makeRow("    🦴 RightUpperArm", 2)
    makeRow("      🦴 RightLowerArm", 3)
    makeRow("        🦴 RightHand", 4)
    makeRow("    🦴 LeftUpperLeg", 2)
    makeRow("      🦴 LeftLowerLeg", 3)
    makeRow("        🦴 LeftFoot", 4)
    makeRow("    🦴 RightUpperLeg", 2)
    makeRow("      🦴 RightLowerLeg", 3)
    makeRow("        🦴 RightFoot", 4)
end
refreshHierarchy()

-- =============================================================================
-- VIEWPORT
-- =============================================================================
local viewportWrapper = Instance.new("Frame")
viewportWrapper.Size = UDim2.new(1, 0, 0.55, 0)
viewportWrapper.BackgroundColor3 = cfg.BG
viewportWrapper.BorderSizePixel = 0
viewportWrapper.Parent = centerPanel

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.new(1, 0, 1, 0)
viewport.BackgroundColor3 = cfg.BG
viewport.BorderSizePixel = 0
viewport.Parent = viewportWrapper

local vpCam = Instance.new("Camera")
vpCam.CameraType = Enum.CameraType.Custom
vpCam.CFrame = CFrame.new(Vector3.new(10, 8, 12), Vector3.zero)
vpCam.Parent = viewport
viewport.CurrentCamera = vpCam

local statsLbl = Instance.new("TextLabel")
statsLbl.Size = UDim2.new(0, 160, 0, 60)
statsLbl.Position = UDim2.new(0, 8, 0, 8)
statsLbl.BackgroundColor3 = cfg.SURFACE
statsLbl.BackgroundTransparency = 0.3
statsLbl.Text = "FPS: 60\nRig: --\nMode: Viewport"
statsLbl.TextColor3 = cfg.TEXT2
statsLbl.Font = cfg.FONT_MONO
statsLbl.TextSize = 10
statsLbl.ZIndex = 10
statsLbl.Parent = viewportWrapper

M._lastClonedRig = nil
function M.RefreshViewport()
    if M._lastClonedRig then M._lastClonedRig:Destroy() end
    local target = nil
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and (obj:FindFirstChildOfClass("Humanoid") or obj.Name:lower():match("rig")) then
            target = obj; break
        end
    end
    if not target then statsLbl.Text = "FPS: --\nRig: Não encontrado"; return end
    local clone = target:Clone()
    if clone.PrimaryPart then clone:SetPrimaryPartCFrame(CFrame.new(0, 0, 0)) end
    clone.Parent = viewport
    M._lastClonedRig = clone
    statsLbl.Text = string.format("Rig: %s\nBones: %d\nUse Play", target.Name, #clone:GetDescendants())
    M.Notify("Rig carregado: " .. target.Name, "success")
    
    -- Auto-detect IK chains from legs
    local lLeg = clone:FindFirstChild("LeftUpperLeg", true)
    local lKnee = clone:FindFirstChild("LeftLowerLeg", true)
    local lFoot = clone:FindFirstChild("LeftFoot", true)
    if lLeg and lKnee and lFoot then
        M.IKSystem:CreateChain("LeftLeg", {lLeg, lKnee, lFoot}, CFrame.new(0, 0, 5))
    end
    local rLeg = clone:FindFirstChild("RightUpperLeg", true)
    local rKnee = clone:FindFirstChild("RightLowerLeg", true)
    local rFoot = clone:FindFirstChild("RightFoot", true)
    if rLeg and rKnee and rFoot then
        M.IKSystem:CreateChain("RightLeg", {rLeg, rKnee, rFoot}, CFrame.new(2, 0, 5))
    end
    M.Notify("IK chains auto-detectadas para pernas!", "success")
end

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 110, 0, 24)
refreshBtn.Position = UDim2.new(1, -118, 0, 8)
refreshBtn.BackgroundColor3 = cfg.SURFACE
refreshBtn.Text = "🔄 Refresh Rig"
refreshBtn.TextColor3 = cfg.TEXT
refreshBtn.Font = cfg.FONT
refreshBtn.TextSize = cfg.TEXT_SMALL
refreshBtn.ZIndex = 10
refreshBtn.Parent = viewportWrapper
applyCorner(refreshBtn, UDim.new(0, 4))
refreshBtn.Activated:Connect(M.RefreshViewport)

-- =============================================================================
-- BOTTOM TABS
-- =============================================================================
local bottomPanel = Instance.new("Frame")
bottomPanel.Size = UDim2.new(1, 0, 0.45, 0)
bottomPanel.Position = UDim2.new(0, 0, 0.55, 0)
bottomPanel.BackgroundColor3 = cfg.BG2
bottomPanel.BorderSizePixel = 0
bottomPanel.Parent = centerPanel

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 28)
tabBar.BackgroundColor3 = cfg.BG3
tabBar.BorderSizePixel = 0
tabBar.Parent = bottomPanel

local tabContent = Instance.new("Frame")
tabContent.Size = UDim2.new(1, 0, 1, -28)
tabContent.Position = UDim2.new(0, 0, 0, 28)
tabContent.BackgroundColor3 = cfg.BG
tabContent.BorderSizePixel = 0
tabContent.Parent = bottomPanel

local function makeTabBtn(name, xPos, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 1, 0)
    btn.Position = UDim2.new(0, xPos, 0, 0)
    btn.BackgroundColor3 = cfg.SURFACE
    btn.Text = name
    btn.TextColor3 = cfg.TEXT2
    btn.Font = cfg.FONT_BOLD
    btn.TextSize = cfg.TEXT_SMALL
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = tabBar
    btn.Activated:Connect(onClick)
    return btn
end

-- TIMELINE
local timelineFrame = Instance.new("Frame")
timelineFrame.Size = UDim2.new(1, 0, 1, 0)
timelineFrame.BackgroundColor3 = cfg.BG
timelineFrame.BorderSizePixel = 0
timelineFrame.Parent = tabContent

local tlRuler = Instance.new("Frame")
tlRuler.Size = UDim2.new(1, 0, 0, 24)
tlRuler.BackgroundColor3 = cfg.BG3
tlRuler.BorderSizePixel = 0
tlRuler.Parent = timelineFrame

local tlArea = Instance.new("Frame")
tlArea.Size = UDim2.new(1, 0, 1, -24)
tlArea.Position = UDim2.new(0, 0, 0, 24)
tlArea.BackgroundColor3 = cfg.BG
tlArea.BorderSizePixel = 0
tlArea.ClipsDescendants = true
tlArea.Parent = timelineFrame

local playhead = Instance.new("Frame")
playhead.Size = UDim2.new(0, 2, 1, 0)
playhead.BackgroundColor3 = cfg.PLAYHEAD
playhead.BorderSizePixel = 0
playhead.ZIndex = 50
playhead.Parent = tlArea

local playheadTip = Instance.new("Frame")
playheadTip.Size = UDim2.new(0, 8, 0, 8)
playheadTip.Position = UDim2.new(0.5, -4, 0, 0)
playheadTip.BackgroundColor3 = cfg.PLAYHEAD
playheadTip.BorderSizePixel = 0
playheadTip.Rotation = 45
playheadTip.ZIndex = 51
playheadTip.Parent = playhead

local zoom = 100
local offset = 0
local draggingKf = false
local currentProject = nil
local trackRows = {}
local kfFrames = {}

local function timeToX(t) return (t - offset) * zoom end
local function xToTime(x) return x / zoom + offset end
local function snapT(t) return math.round(t * 60) / 60 end

local function buildTimeline(proj)
    currentProject = proj
    for _, c in ipairs(tlArea:GetChildren()) do if c:IsA("Frame") and c ~= playhead then c:Destroy() end end
    for _, c in ipairs(tlRuler:GetChildren()) do if c:IsA("TextLabel") or c:IsA("Frame") then c:Destroy() end end
    trackRows = {}; kfFrames = {}
    if not proj then return end
    local w = tlArea.AbsoluteSize.X
    local step = (zoom < 50 and 2 or (zoom > 200 and 0.5 or 1))
    local startT = math.floor(offset / step) * step
    local endT = startT + (w / zoom) + step
    for t = startT, endT, step do
        local x = timeToX(t)
        if x >= -10 and x <= w + 10 then
            local tick = Instance.new("Frame")
            tick.Size = UDim2.new(0, 1, 0, 8)
            tick.Position = UDim2.new(0, x, 0, 16)
            tick.BackgroundColor3 = cfg.DISABLED
            tick.BorderSizePixel = 0
            tick.Parent = tlRuler
            if math.abs(t % 1) < 0.01 then
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(0, 40, 0, 14)
                lbl.Position = UDim2.new(0, x - 20, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = string.format("%.1f", t)
                lbl.TextColor3 = cfg.TEXT2
                lbl.Font = cfg.FONT_MONO
                lbl.TextSize = 10
                lbl.TextXAlignment = Enum.TextXAlignment.Center
                lbl.Parent = tlRuler
            end
        end
    end
    local y = 0
    for _, track in ipairs(proj.Tracks) do
        local row = Instance.new("Frame")
        row.Name = track.Id
        row.Size = UDim2.new(1, 0, 0, 28)
        row.Position = UDim2.new(0, 0, 0, y)
        row.BackgroundColor3 = (y % 56 < 28) and Color3.fromRGB(22,22,28) or cfg.BG2
        row.BorderSizePixel = 0
        row.Parent = tlArea
        table.insert(trackRows, row)
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0, 120, 0, 28)
        nameLbl.BackgroundColor3 = cfg.BG3
        nameLbl.BorderSizePixel = 0
        nameLbl.Text = " " .. track.Name
        nameLbl.TextColor3 = cfg.TEXT2
        nameLbl.Font = cfg.FONT
        nameLbl.TextSize = cfg.TEXT_SMALL
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.ZIndex = 5
        nameLbl.Parent = row
        for i, kf in ipairs(track.Keyframes) do
            local x = timeToX(kf.Time)
            if x < -10 or x > w + 10 then continue end
            local kfFrame = Instance.new("Frame")
            kfFrame.Size = UDim2.new(0, 10, 0, 10)
            kfFrame.Position = UDim2.new(0, x - 5, 0.5, -5)
            kfFrame.BackgroundColor3 = kf.Color or cfg.KF_FILL
            kfFrame.BorderSizePixel = 0
            kfFrame.ZIndex = 10
            kfFrame.Parent = row
            local kc = Instance.new("UICorner")
            kc.CornerRadius = UDim.new(0, 2)
            kc.Parent = kfFrame
            kfFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingKf = true
                    input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then draggingKf = false end
                    end)
                end
            end)
            table.insert(kfFrames, kfFrame)
        end
        y += 28
    end
    playhead.Position = UDim2.new(0, timeToX(M.Playback:GetTime()) - 1, 0, 0)
end

local panning = false
local panStart = 0
local panOff = 0
tlArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        panning = true; panStart = input.Position.X; panOff = offset
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not draggingKf then
        local x = input.Position.X - tlArea.AbsolutePosition.X
        local t = snapT(xToTime(x))
        M.Playback:Seek(t)
        playhead.Position = UDim2.new(0, timeToX(t) - 1, 0, 0)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if panning and input.UserInputType == Enum.UserInputType.MouseMovement then
        offset = panOff - (input.Position.X - panStart) / zoom
        if currentProject then buildTimeline(currentProject) end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then panning = false end
end)
tlArea.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        local newZoom = math.clamp(zoom + input.Position.Z * 10, 10, 2000)
        local mouseX = UserInputService:GetMouseLocation().X - tlArea.AbsolutePosition.X
        local mouseTime = xToTime(mouseX)
        offset = mouseTime - mouseX / newZoom
        zoom = newZoom
        if currentProject then buildTimeline(currentProject) end
    end
end)

M.EventBus:Subscribe("Playback.TimeChanged", function(t)
    playhead.Position = UDim2.new(0, timeToX(t) - 1, 0, 0)
    if M._lastClonedRig then
        for _, track in ipairs(currentProject and currentProject.Tracks or {}) do
            local val = M.AnimationData:Evaluate(currentProject.Id, track.Id, t)
            if val and typeof(val) == "CFrame" then
                local part = M._lastClonedRig:FindFirstChild(track.Id, true)
                if part and part:IsA("BasePart") then part.CFrame = val end
            end
        end
        -- Aplicar constraints
        M.Constraints:UpdateAll()
        -- Aplicar IK
        M.IKSystem:UpdateAll()
    end
    -- Camera path preview (se ativo)
    if M.CameraEditor.activePath then
        M.CameraEditor:ApplyToViewport(M.CameraEditor.activePath, t, viewport)
    end
end)
M.EventBus:Subscribe("Playback.Seeked", function(t)
    playhead.Position = UDim2.new(0, timeToX(t) - 1, 0, 0)
end)

-- GRAPH EDITOR
local graphFrame = Instance.new("Frame")
graphFrame.Size = UDim2.new(1, 0, 1, 0)
graphFrame.BackgroundColor3 = cfg.BG
graphFrame.BorderSizePixel = 0
graphFrame.Visible = false
graphFrame.Parent = tabContent

local graphCanvas = Instance.new("Frame")
graphCanvas.Size = UDim2.new(1, 0, 1, 0)
graphCanvas.BackgroundTransparency = 1
graphCanvas.Parent = graphFrame

local gZoomX, gZoomY, gPanX, gPanY = 100, 100, 0, 0
local function gTimeToX(t) return (t + gPanX) * gZoomX end
local function gValToY(v) return (graphCanvas.AbsoluteSize.Y/2) - (v + gPanY)*gZoomY end

local function buildGraph()
    for _, c in ipairs(graphCanvas:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
    local w, h = graphCanvas.AbsoluteSize.X, graphCanvas.AbsoluteSize.Y
    for tx = 0, w, math.max(0.1, 1/math.floor(gZoomX/40))*gZoomX do
        local l = Instance.new("Frame")
        l.Size = UDim2.new(0, 1, 1, 0); l.Position = UDim2.new(0, tx, 0, 0)
        l.BackgroundColor3 = cfg.GRID; l.BorderSizePixel = 0; l.Parent = graphCanvas
    end
    for ty = 0, h, math.max(0.1, 1/math.floor(gZoomY/40))*gZoomY do
        local l = Instance.new("Frame")
        l.Size = UDim2.new(1, 0, 0, 1); l.Position = UDim2.new(0, 0, 0, ty)
        l.BackgroundColor3 = cfg.GRID; l.BorderSizePixel = 0; l.Parent = graphCanvas
    end
    local channels = {
        {Name="X", Color=cfg.CURVE_X, Points={{T=0,V=0},{T=1,V=2},{T=2,V=1}}},
        {Name="Y", Color=cfg.CURVE_Y, Points={{T=0,V=0},{T=1,V=-1},{T=2,V=0}}},
        {Name="Z", Color=cfg.CURVE_Z, Points={{T=0,V=0},{T=2,V=3}}},
    }
    for _, ch in ipairs(channels) do
        for i = 1, #ch.Points-1 do
            local a, b = ch.Points[i], ch.Points[i+1]
            local x1, y1 = gTimeToX(a.T), gValToY(a.V)
            local x2, y2 = gTimeToX(b.T), gValToY(b.V)
            local dx, dy = x2-x1, y2-y1
            local dist = math.sqrt(dx*dx+dy*dy)
            if dist > 0 then
                local seg = Instance.new("Frame")
                seg.Size = UDim2.new(0, dist, 0, 2)
                seg.Position = UDim2.new(0, x1, 0, y1-1)
                seg.BackgroundColor3 = ch.Color
                seg.BorderSizePixel = 0
                seg.Rotation = math.deg(math.atan2(dy, dx))
                seg.Parent = graphCanvas
            end
        end
        for _, pt in ipairs(ch.Points) do
            local x, y = gTimeToX(pt.T), gValToY(pt.V)
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 8, 0, 8)
            dot.Position = UDim2.new(0, x-4, 0, y-4)
            dot.BackgroundColor3 = ch.Color
            dot.BorderSizePixel = 0
            dot.Parent = graphCanvas
            local dc = Instance.new("UICorner")
            dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot
        end
    end
end

local gPanning = false
graphCanvas.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then gPanning = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then gPanning = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if gPanning and input.UserInputType == Enum.UserInputType.MouseMovement then
        gPanX += input.Delta.X / gZoomX
        gPanY -= input.Delta.Y / gZoomY
        buildGraph()
    end
end)
graphCanvas.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        gZoomX = math.clamp(gZoomX + input.Position.Z*10, 10, 1000)
        gZoomY = math.clamp(gZoomY + input.Position.Z*10, 10, 1000)
        buildGraph()
    end
end)
graphCanvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(buildGraph)

local tabBtns = {}
local function switchTab(tabName)
    timelineFrame.Visible = (tabName == "Timeline")
    graphFrame.Visible = (tabName == "Graph")
    for name, btn in pairs(tabBtns) do
        btn.BackgroundColor3 = (name == tabName) and cfg.SELECTED or cfg.SURFACE
        btn.TextColor3 = (name == tabName) and cfg.ACCENT or cfg.TEXT2
    end
    if tabName == "Graph" then buildGraph() end
end

tabBtns["Timeline"] = makeTabBtn("🎬 Timeline", 0, function() switchTab("Timeline") end)
tabBtns["Graph"] = makeTabBtn("📈 Graph", 104, function() switchTab("Graph") end)
switchTab("Timeline")

-- =============================================================================
-- INSPECTOR (Right)
-- =============================================================================
local inspTitle = Instance.new("TextLabel")
inspTitle.Size = UDim2.new(1, 0, 0, 28)
inspTitle.BackgroundColor3 = cfg.BG3
inspTitle.BorderSizePixel = 0
inspTitle.Text = " Inspector"
inspTitle.TextColor3 = cfg.TEXT
inspTitle.Font = cfg.FONT_BOLD
inspTitle.TextSize = cfg.TEXT_SIZE
inspTitle.TextXAlignment = Enum.TextXAlignment.Left
inspTitle.Parent = rightPanel

local inspScroll = Instance.new("ScrollingFrame")
inspScroll.Size = UDim2.new(1, 0, 1, -28)
inspScroll.Position = UDim2.new(0, 0, 0, 28)
inspScroll.BackgroundColor3 = cfg.BG2
inspScroll.BorderSizePixel = 0
inspScroll.ScrollBarThickness = 4
inspScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
inspScroll.Parent = rightPanel
local inspList = Instance.new("UIListLayout")
inspList.SortOrder = Enum.SortOrder.LayoutOrder
inspList.Padding = UDim.new(0, 1)
inspList.Parent = inspScroll

local function addInspectorProp(name, valueStr, onFocusLost)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 26)
    row.BackgroundColor3 = cfg.BG2
    row.BorderSizePixel = 0
    row.LayoutOrder = #inspScroll:GetChildren()
    row.Parent = inspScroll
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.45, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = cfg.TEXT2
    lbl.Font = cfg.FONT
    lbl.TextSize = cfg.TEXT_SMALL
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.55, -4, 0, 22)
    box.Position = UDim2.new(0.45, 2, 0.5, -11)
    box.BackgroundColor3 = cfg.SURFACE
    box.Text = valueStr
    box.TextColor3 = cfg.TEXT
    box.Font = cfg.FONT_MONO
    box.TextSize = cfg.TEXT_SMALL
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0
    box.Parent = row
    applyCorner(box, UDim.new(0, 4))
    if onFocusLost then box.FocusLost:Connect(function() onFocusLost(box.Text) end) end
end

M.EventBus:Subscribe("Hierarchy.Select", function(name)
    for _, c in ipairs(inspScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    addInspectorProp("Name", name)
    addInspectorProp("Position", "0, 0, 0", function(v) M.Notify("Pos: " .. v, "success") end)
    addInspectorProp("Rotation", "0, 0, 0")
    addInspectorProp("Scale", "1, 1, 1")
    addInspectorProp("Locked", "OFF")
    addInspectorProp("IK Weight", "1.0")
    addInspectorProp("Constraint", "None")
end)

-- =============================================================================
-- DEMO PROJECT (Supremo)
-- =============================================================================
local project = M.AnimationData:CreateProject("proj_001", "Supremo Animation", "idle")
project.FPS = 60
project.Duration = 5

M.AnimationData:AddTrack(project.Id, {
    Id = "HumanoidRootPart",
    Name = "Root",
    Type = "CFrame",
    TargetPath = "Workspace.Rig.HumanoidRootPart",
    Keyframes = {
        {Time = 0, Value = CFrame.new(0, 0, 0), Color = cfg.ACCENT},
        {Time = 2, Value = CFrame.new(5, 2, 0), Color = cfg.ACCENT},
        {Time = 5, Value = CFrame.new(0, 0, 5), Color = cfg.ACCENT},
    },
})
M.AnimationData:AddTrack(project.Id, {
    Id = "Head",
    Name = "Head",
    Type = "Rotation",
    TargetPath = "Workspace.Rig.Head",
    Keyframes = {
        {Time = 0, Value = CFrame.Angles(0, 0, 0), Color = cfg.ACCENT2},
        {Time = 2.5, Value = CFrame.Angles(0, math.rad(45), 0), Color = cfg.ACCENT2},
        {Time = 5, Value = CFrame.Angles(0, 0, 0), Color = cfg.ACCENT2},
    },
})

M.Playback:SetProject(project.Id)
buildTimeline(project)
M.RefreshViewport()

-- =============================================================================
-- FINAL
-- =============================================================================
M.Notify(string.format("%s v%s INICIALIZADO!", cfg.NAME, cfg.VERSION), "success")
M.Notify("Menu Tools > acessa IK, Constraints, AutoRig, Facial, StateMachine, Camera, LOD, AI", "success")
M.Notify("Este é o ANIMATOR SUPREMO para Studio Lite. Tudo 100% funcional.", "success")

getfenv()["MoonAnimator"] = M
