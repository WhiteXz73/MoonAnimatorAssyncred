--!strict
--[[
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║           MOON ANIMATOR ASSYNCRED — SUPREMO MOBILE EDITION                   ║
    ║                    Delta Executor / Studio Lite / Touch                      ║
    ║                v3.0.0-Mobile — UI Otimizada para Celular                   ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    
    MODO MOBILE (padrão):
    • 5 Abas fullscreen na parte inferior: Scene | Keys | Curves | Rig | Tools
    • Timeline/Graph com PAN (1 dedo) e PINCH ZOOM (2 dedos)
    • Botões mínimo 44px para touch
    • Todos os editores abrem como overlays fullscreen com botão Voltar gigante
    • Viewport ocupa a tela inteira na aba Scene
    • Inspector integrado no toque da Hierarchy
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Limpar execuções anteriores
for _, v in ipairs(playerGui:GetChildren()) do
    if v.Name:match("MoonAnimator") then v:Destroy() end
end

local M = {}

-- =============================================================================
-- CONFIG & THEME (Alto contraste mobile)
-- =============================================================================
M.Config = {
    VERSION = "3.0.0-Mobile",
    NAME = "Moon Animator Supremo Mobile",
    FPS = 60,
    ACCENT = Color3.fromRGB(0, 220, 255),
    ACCENT2 = Color3.fromRGB(200, 90, 255),
    ACCENT_OK = Color3.fromRGB(0, 240, 160),
    BG = Color3.fromRGB(8, 8, 12),
    BG2 = Color3.fromRGB(16, 16, 22),
    BG3 = Color3.fromRGB(24, 24, 34),
    SURFACE = Color3.fromRGB(36, 36, 50),
    SURFACE_HL = Color3.fromRGB(50, 50, 68),
    TEXT = Color3.fromRGB(245, 248, 255),
    TEXT2 = Color3.fromRGB(180, 185, 205),
    DISABLED = Color3.fromRGB(90, 92, 110),
    BORDER = Color3.fromRGB(55, 58, 75),
    HOVER = Color3.fromRGB(55, 55, 75),
    SELECTED = Color3.fromRGB(0, 100, 140),
    PLAYHEAD = Color3.fromRGB(255, 40, 80),
    KF_FILL = Color3.fromRGB(0, 210, 255),
    CURVE_X = Color3.fromRGB(255, 70, 100),
    CURVE_Y = Color3.fromRGB(60, 255, 130),
    CURVE_Z = Color3.fromRGB(70, 150, 255),
    GRID = Color3.fromRGB(35, 35, 48),
    FONT = Enum.Font.GothamMedium,
    FONT_BOLD = Enum.Font.GothamBold,
    FONT_MONO = Enum.Font.RobotoMono,
    TEXT_SIZE = 15,
    TEXT_SMALL = 13,
    RADIUS = UDim.new(0, 8),
}
local cfg = M.Config

-- =============================================================================
-- MOBILE DETECT
-- =============================================================================
local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)

-- =============================================================================
-- EVENTBUS
-- =============================================================================
M.EventBus = { _events = {} }
function M.EventBus:Subscribe(event, callback, id)
    if not self._events[event] then self._events[event] = {} end
    local connId = id or (event.."_"..tostring(tick()).."_"..tostring(math.random(1,100000)))
    self._events[event][connId] = callback
    return connId
end
function M.EventBus:Emit(event, ...)
    if self._events[event] then for _, cb in pairs(self._events[event]) do task.spawn(cb,...) end end
end

-- =============================================================================
-- FILESYSTEM
-- =============================================================================
M.FileSystem = { _cache={}, _meta={} }
function M.FileSystem:Write(path,data)
    self._cache[path]=data
    self._meta[path]={modified=tick(),version=(self._meta[path]and self._meta[path].version or 0)+1}
end
function M.FileSystem:Read(path) return self._cache[path] end
function M.FileSystem:Exists(path) return self._cache[path]~=nil end

-- =============================================================================
-- ANIMATION DATA
-- =============================================================================
M.AnimationData = { _projects={} }
function M.AnimationData:CreateProject(id,name,category)
    local proj={Id=id,Name=name,Category=category or"idle",FPS=60,Duration=5,Tracks={},Markers={},Cameras={},States={},FaceTracks={}}
    self._projects[id]=proj; return proj
end
function M.AnimationData:GetProject(id) return self._projects[id] end
function M.AnimationData:AddTrack(projectId,track)
    local proj=self._projects[projectId]; if proj then table.insert(proj.Tracks,track) end
end
function M.AnimationData:Evaluate(projectId,trackId,time)
    local proj=self._projects[projectId]; if not proj then return nil end
    for _,t in ipairs(proj.Tracks) do
        if t.Id==trackId then
            local kfs=t.Keyframes; if #kfs==0 then return nil end
            if time<=kfs[1].Time then return kfs[1].Value end
            if time>=kfs[#kfs].Time then return kfs[#kfs].Value end
            for i=1,#kfs-1 do
                local a,b=kfs[i],kfs[i+1]
                if time>=a.Time and time<=b.Time then
                    local alpha=(time-a.Time)/(b.Time-a.Time)
                    if typeof(a.Value)=="CFrame" then return a.Value:Lerp(b.Value,alpha)
                    elseif typeof(a.Value)=="Vector3" then return a.Value:Lerp(b.Value,alpha)
                    elseif typeof(a.Value)=="number" then return a.Value+(b.Value-a.Value)*alpha
                    else return a.Value end
                end
            end
        end
    end
    return nil
end

-- =============================================================================
-- PLAYBACK
-- =============================================================================
M.Playback = {playing=false,time=0,speed=1,loop=true,projectId="",fps=60,conn=nil}
function M.Playback:SetProject(id)
    self.projectId=id; local proj=M.AnimationData:GetProject(id); if proj then self.fps=proj.FPS end
end
function M.Playback:Play()
    if self.playing then return end; self.playing=true; M.EventBus:Emit("Playback.Started")
    local last=tick(); self.conn=RunService.Heartbeat:Connect(function()
        local now=tick(); local dt=now-last; last=now
        if not self.playing then return end; self.time+=dt*self.speed
        local proj=M.AnimationData:GetProject(self.projectId)
        if proj then if self.time>proj.Duration then if self.loop then self.time=0 else self.time=proj.Duration; self:Pause() end end end
        M.EventBus:Emit("Playback.TimeChanged",self.time)
    end)
end
function M.Playback:Pause()
    self.playing=false; if self.conn then self.conn:Disconnect(); self.conn=nil end
    M.EventBus:Emit("Playback.Paused",self.time)
end
function M.Playback:Stop() self:Pause(); self.time=0; M.EventBus:Emit("Playback.Stopped",0) end
function M.Playback:Seek(t)
    local proj=M.AnimationData:GetProject(self.projectId)
    if proj then self.time=math.clamp(t,0,proj.Duration) end
    M.EventBus:Emit("Playback.Seeked",self.time)
end
function M.Playback:GetTime() return self.time end
function M.Playback:IsPlaying() return self.playing end

-- =============================================================================
-- IK SYSTEM
-- =============================================================================
M.IKSystem = { chains={} }
function M.IKSystem:CreateChain(name,joints,targetCFrame,pole)
    self.chains[name]={Name=name,Joints=joints,Target=targetCFrame,Pole=pole or Vector3.zero,Enabled=true,Iterations=15}
end
function M.IKSystem:RemoveChain(name) self.chains[name]=nil end
function M.IKSystem:SetTarget(name,cf) local c=self.chains[name]; if c then c.Target=cf end end
function M.IKSystem:FABRIK(name)
    local chain=self.chains[name]; if not chain then return end
    local joints=chain.Joints; local n=#joints; if n<2 then return end
    local target=chain.Target.Position; local positions={}; local dists={}
    for i,j in ipairs(joints) do positions[i]=j.Position end
    for i=1,n-1 do dists[i]=(positions[i+1]-positions[i]).Magnitude end
    local totalLen=0; for _,d in ipairs(dists) do totalLen+=d end
    local rootToTarget=(target-positions[1]).Magnitude
    if rootToTarget>totalLen then
        local dir=(target-positions[1]).Unit
        for i=2,n do positions[i]=positions[i-1]+dir*dists[i-1] end
    else
        for _=1,chain.Iterations do
            positions[n]=target
            for i=n-1,1,-1 do local dir=(positions[i]-positions[i+1]).Unit; positions[i]=positions[i+1]+dir*dists[i] end
            positions[1]=joints[1].Position
            for i=2,n do local dir=(positions[i]-positions[i-1]).Unit; positions[i]=positions[i-1]+dir*dists[i-1] end
        end
    end
    for i,j in ipairs(joints) do
        if i<n then local look=CFrame.lookAt(positions[i],positions[i+1]); j.CFrame=CFrame.new(positions[i])*look.Rotation
        else j.CFrame=CFrame.new(positions[i])*chain.Target.Rotation end
    end
end
function M.IKSystem:CCD(name)
    local chain=self.chains[name]; if not chain then return end
    local joints=chain.Joints; local n=#joints; if n<2 then return end
    local target=chain.Target.Position
    for _=1,chain.Iterations do
        for i=n-1,1,-1 do
            local jointPos=joints[i].Position
            local toEffector=(joints[n].Position-jointPos).Unit
            local toTarget=(target-jointPos).Unit
            local axis=toEffector:Cross(toTarget)
            if axis.Magnitude>0.001 then
                local angle=math.acos(math.clamp(toEffector:Dot(toTarget),-1,1))
                local rot=CFrame.fromAxisAngle(axis.Unit,angle)
                joints[i].CFrame=joints[i].CFrame*rot
            end
        end
        if (joints[n].Position-target).Magnitude<0.01 then break end
    end
end
function M.IKSystem:UpdateAll() for name,chain in pairs(self.chains) do if chain.Enabled then self:FABRIK(name) end end end
function M.IKSystem:FootPlant(footPart,groundY)
    local pos=footPart.Position
    footPart.CFrame=CFrame.new(Vector3.new(pos.X,groundY+footPart.Size.Y/2,pos.Z))*footPart.CFrame.Rotation
end

-- =============================================================================
-- CONSTRAINTS
-- =============================================================================
M.Constraints = { list={} }
function M.Constraints:AddConstraint(cType,source,target,settings)
    table.insert(self.list,{Type=cType,Source=source,Target=target,Active=true,Settings=settings or{}})
end
function M.Constraints:RemoveByTarget(target) for i=#self.list,1,-1 do if self.list[i].Target==target then table.remove(self.list,i) end end end
function M.Constraints:UpdateAll()
    for _,c in ipairs(self.list) do
        if not c.Active then continue end; local s=c.Source; local t=c.Target
        if not s or not t then continue end
        if c.Type=="Aim" and s:IsA("BasePart") and t:IsA("BasePart") then t.CFrame=CFrame.lookAt(t.Position,s.Position)
        elseif c.Type=="Parent" and s:IsA("BasePart") and t:IsA("BasePart") then t.CFrame=s.CFrame*(c.Settings.Offset or CFrame.new())
        elseif c.Type=="CopyTransform" then if s:IsA("BasePart") and t:IsA("BasePart") then t.CFrame=s.CFrame elseif s:IsA("Motor6D") and t:IsA("Motor6D") then t.Transform=s.Transform end end
    end
end

-- =============================================================================
-- AUTO-RIG
-- =============================================================================
M.AutoRig = {}
function M.AutoRig:Analyze(model)
    local rigType="Unknown"; local bones={}
    if model:FindFirstChild("Humanoid") then
        if model:FindFirstChild("Head") and model:FindFirstChild("Torso") then
            if model:FindFirstChild("Left Arm") then rigType="R6" else rigType="R15" end
        end
    end
    for _,c in ipairs(model:GetDescendants()) do if c:IsA("BasePart") then table.insert(bones,c.Name) end; if c:IsA("Motor6D") then table.insert(bones,c.Name.."(M6D)") end end
    return rigType,bones
end
function M.AutoRig:BuildTemplate(model,rigType)
    if rigType=="R15" then return {{Name="HumanoidRootPart"},{Name="UpperTorso"},{Name="LowerTorso"},{Name="Head"},{Name="LeftUpperArm"},{Name="LeftLowerArm"},{Name="LeftHand"},{Name="RightUpperArm"},{Name="RightLowerArm"},{Name="RightHand"},{Name="LeftUpperLeg"},{Name="LeftLowerLeg"},{Name="LeftFoot"},{Name="RightUpperLeg"},{Name="RightLowerLeg"},{Name="RightFoot"}}
    elseif rigType=="R6" then return {{Name="HumanoidRootPart"},{Name="Torso"},{Name="Head"},{Name="Left Arm"},{Name="Right Arm"},{Name="Left Leg"},{Name="Right Leg"}} end
    return {}
end

-- =============================================================================
-- FACIAL SYSTEM
-- =============================================================================
M.FacialSystem = {
    emotions={Neutral={},Happy={Jaw=-0.05},Sad={Jaw=0.02},Angry={Jaw=0.05},Surprised={Jaw=-0.1}},
    current="Neutral", eyeTarget=nil
}
function M.FacialSystem:SetEmotion(emotionName,rigModel)
    self.current=emotionName; if not rigModel then return end
    local head=rigModel:FindFirstChild("Head",true); if head and head:IsA("BasePart") then
        for _,c in ipairs(head:GetChildren()) do if c:IsA("BasePart") and c.Name:match("Face") then c.CFrame=c.CFrame+Vector3.new(0,(self.emotions[emotionName].Jaw or 0),0) end end
    end
    M.EventBus:Emit("Facial.EmotionChanged",emotionName)
end
function M.FacialSystem:SetEyeTarget(worldPos,rigModel)
    self.eyeTarget=worldPos; if not rigModel then return end
    local head=rigModel:FindFirstChild("Head",true)
    if head then for _,c in ipairs(head:GetChildren()) do if c.Name:match("Eye") or c.Name:match("eye") then c.CFrame=CFrame.lookAt(c.Position,worldPos) end end end
end
function M.FacialSystem:LipSync(phoneme,rigModel)
    if not rigModel then return end; local head=rigModel:FindFirstChild("Head",true); if not head then return end
    local jaw=head:FindFirstChild("Jaw") or head; local openings={A=0.3,O=0.25,E=0.15,I=0.1,U=0.12,M=0.0,rest=0.0}
    local open=openings[phoneme] or 0; if jaw and jaw:IsA("BasePart") then jaw.CFrame=jaw.CFrame+Vector3.new(0,-open,0) end
end

-- =============================================================================
-- STATE MACHINE
-- =============================================================================
M.StateMachine = { machines={}, activeMachine=nil }
function M.StateMachine:Create(id,name)
    local sm={Id=id,Name=name,States={},Transitions={},Parameters={},EntryState=""}
    self.machines[id]=sm; return sm
end
function M.StateMachine:AddState(machineId,state) local sm=self.machines[machineId]; if sm then table.insert(sm.States,state) end end
function M.StateMachine:AddTransition(machineId,trans) local sm=self.machines[machineId]; if sm then table.insert(sm.Transitions,trans) end end
function M.StateMachine:SetParameter(machineId,param,value) local sm=self.machines[machineId]; if sm then sm.Parameters[param]=value end end
function M.StateMachine:Evaluate(machineId)
    local sm=self.machines[machineId]; if not sm then return nil end
    for _,s in ipairs(sm.States) do if s.Id==sm.EntryState then return s end end; return nil
end

-- =============================================================================
-- CAMERA EDITOR
-- =============================================================================
M.CameraEditor = { paths={}, activePath=nil }
function M.CameraEditor:CreatePath(name) local path={Name=name,Keyframes={},Duration=5}; self.paths[name]=path; return path end
function M.CameraEditor:AddKeyframe(pathName,time,cf,fov,shakeAmp,dofDist)
    local p=self.paths[pathName]; if not p then return end
    table.insert(p.Keyframes,{Time=time,CFrame=cf,FOV=fov or 70,ShakeAmp=shakeAmp or 0,DOFDist=dofDist or 0})
    table.sort(p.Keyframes,function(a,b) return a.Time<b.Time end)
end
function M.CameraEditor:Evaluate(pathName,time)
    local p=self.paths[pathName]; if not p or #p.Keyframes==0 then return nil end
    local kfs=p.Keyframes; if time<=kfs[1].Time then return kfs[1] end; if time>=kfs[#kfs].Time then return kfs[#kfs] end
    for i=1,#kfs-1 do local a,b=kfs[i],kfs[i+1]; if time>=a.Time and time<=b.Time then
        local alpha=(time-a.Time)/(b.Time-a.Time)
        return {CFrame=a.CFrame:Lerp(b.CFrame,alpha),FOV=a.FOV+(b.FOV-a.FOV)*alpha,ShakeAmp=a.ShakeAmp+(b.ShakeAmp-a.ShakeAmp)*alpha,DOFDist=a.DOFDist+(b.DOFDist-a.DOFDist)*alpha}
    end end; return nil
end
function M.CameraEditor:ApplyToViewport(pathName,time,vpFrame)
    local v=self:Evaluate(pathName,time); if not v then return end
    local cam=vpFrame and vpFrame.CurrentCamera; if not cam then return end
    local shake=Vector3.new((math.random()-0.5)*2*v.ShakeAmp,(math.random()-0.5)*2*v.ShakeAmp,(math.random()-0.5)*2*v.ShakeAmp)
    cam.CFrame=v.CFrame+shake; cam.FieldOfView=v.FOV
    local blur=vpFrame:FindFirstChildOfClass("BlurEffect"); if blur then blur.Size=v.DOFDist end
end

-- =============================================================================
-- IMPORTER
-- =============================================================================
M.Importer = {}
function M.Importer:FromTable(data,projectId)
    local proj=M.AnimationData:CreateProject(projectId,data.Name or "Imported",data.Category or "idle")
    proj.FPS=data.FPS or 60; proj.Duration=data.Duration or 5
    for _,t in ipairs(data.Tracks or {}) do
        local track={Id=t.Id,Name=t.Name,Type=t.Type,TargetPath=t.TargetPath,Keyframes={}}
        for _,kf in ipairs(t.Keyframes or {}) do
            local val=kf.Value; if t.Type=="CFrame" and typeof(val)~="CFrame" then val=CFrame.new(val[1]or 0,val[2]or 0,val[3]or 0) end
            table.insert(track.Keyframes,{Time=kf.Time,Value=val,Interpolation=kf.Interpolation or "Linear"})
        end
        M.AnimationData:AddTrack(projectId,track)
    end
    M.Notify("Importado: "..projectId,"success")
end
function M.Importer:FromJSON(jsonStr,projectId)
    local ok,data=pcall(function() return HttpService:JSONDecode(jsonStr) end)
    if ok then self:FromTable(data,projectId) else M.Notify("Erro JSON","error") end
end

-- =============================================================================
-- COLLAB
-- =============================================================================
M.Collaboration = {sessionId=nil,peers={},host=false}
function M.Collaboration:Host(name) self.host=true; self.sessionId=name; M.Notify("Host: "..name,"success") end
function M.Collaboration:Join(id) self.sessionId=id; M.Notify("Join: "..id,"success") end

-- =============================================================================
-- LOD
-- =============================================================================
M.LODSystem = { levels={{dist=0,skip=0,bones=99},{dist=50,skip=1,bones=32},{dist=120,skip=2,bones=16},{dist=250,skip=4,bones=8}} }
function M.LODSystem:GetLevel(distance)
    for i=#self.levels,1,-1 do if distance>=self.levels[i].dist then return self.levels[i] end end; return self.levels[1]
end

-- =============================================================================
-- MOTION MATCHING
-- =============================================================================
M.MotionMatching = { poseDB={} }
function M.MotionMatching:RecordPose(animId,time,poseData) table.insert(self.poseDB,{AnimId=animId,Time=time,Pose=poseData,Velocity=poseData.Velocity or Vector3.zero}) end
function M.MotionMatching:FindBestMatch(currentPose,desiredVelocity)
    local best=nil; local bestScore=math.huge
    for _,entry in ipairs(self.poseDB) do
        local score=0
        for k,v in pairs(currentPose) do if entry.Pose[k] then score+=(v-entry.Pose[k]).Magnitude end end
        score+=(desiredVelocity-entry.Velocity).Magnitude*2
        if score<bestScore then bestScore=score; best=entry end
    end; return best
end
function M.MotionMatching:SuggestTransition(fromAnim,toAnimSet)
    local suggestions={}; for _,animId in ipairs(toAnimSet) do table.insert(suggestions,{AnimId=animId,Score=math.random()}) end
    table.sort(suggestions,function(a,b) return a.Score<b.Score end); return suggestions[1]
end

-- =============================================================================
-- PROCEDURAL
-- =============================================================================
M.ProceduralMotion = { layers={}, conn=nil }
function M.ProceduralMotion:AddLayer(id,config) self.layers[id]=config end
function M.ProceduralMotion:Start()
    if self.conn then return end; local t=0
    self.conn=RunService.Heartbeat:Connect(function(dt)
        t+=dt
        for _,layer in pairs(self.layers) do
            if layer.Type=="Breathing" and layer.Part then layer.Part.CFrame=layer.BaseCF+Vector3.new(0,math.sin(t*layer.Speed)*layer.Amplitude,0)
            elseif layer.Type=="Recoil" and layer.Part then layer.Current=layer.Current:Lerp(Vector3.zero,dt*layer.Recovery); layer.Part.CFrame=layer.Part.CFrame*CFrame.new(layer.Current)
            elseif layer.Type=="Lean" and layer.Part then layer.Part.CFrame=layer.BaseCF*CFrame.Angles(0,0,math.sin(t*layer.Speed)*layer.Amplitude) end
        end
    end)
end
function M.ProceduralMotion:Stop() if self.conn then self.conn:Disconnect(); self.conn=nil end end

-- =============================================================================
-- EXPORT ENGINE
-- =============================================================================
M.AnimationCategories = {
    {Id="idle",Label="Idle",Desc="Loop contínuo"},
    {Id="core",Label="Core",Desc="Locomoção base"},
    {Id="movement",Label="Movement",Desc="Parkour/vault/roll"},
    {Id="actions",Label="Actions",Desc="One-shot ataques/emotes"},
    {Id="tool",Label="Tool",Desc="Armas/equip"},
}
function M.ExportAnimation(projectId,rigModelName)
    local proj=M.AnimationData:GetProject(projectId); if not proj then return nil,"Projeto não encontrado" end
    local rigName=rigModelName or "Character"; local catInfo=""
    for _,c in ipairs(M.AnimationCategories) do if c.Id==proj.Category then catInfo=string.format("-- Tipo: %s | %s\n",c.Label,c.Desc); break end end
    local code={}
    table.insert(code,"--!strict"); table.insert(code,"--[[ ANIMAÇÃO MOON ANIMATOR SUPREMO"); table.insert(code,string.format("     Projeto: %s | ID: %s | Categoria: %s",proj.Name,proj.Id,proj.Category)); table.insert(code,string.format("     Duração: %.2fs | FPS: %d",proj.Duration,proj.FPS)); table.insert(code,"--]]"); table.insert(code,"")
    table.insert(code,catInfo); table.insert(code,"local RunService=game:GetService('RunService')"); table.insert(code,"local Players=game:GetService('Players')")
    table.insert(code,string.format("local RIG_NAME='%s'",rigName)); table.insert(code,"local ANIM_DATA={")
    table.insert(code,string.format("    Name='%s',",proj.Name)); table.insert(code,string.format("    Category='%s',",proj.Category)); table.insert(code,string.format("    Duration=%.3f,",proj.Duration)); table.insert(code,string.format("    FPS=%d,",proj.FPS)); table.insert(code,"    Tracks={")
    for _,track in ipairs(proj.Tracks) do
        table.insert(code,string.format("        ['%s']={",track.Id)); table.insert(code,string.format("            Type='%s',",track.Type)); table.insert(code,string.format("            TargetPath='%s',",track.TargetPath or "")); table.insert(code,"            Keyframes={")
        for _,kf in ipairs(track.Keyframes) do
            local valStr="nil"; if typeof(kf.Value)=="CFrame" then local p=kf.Value.Position; local rX,rY,rZ=kf.Value:ToEulerAnglesXYZ(); valStr=string.format("CFrame.new(%.4f,%.4f,%.4f)*CFrame.Angles(%.4f,%.4f,%.4f)",p.X,p.Y,p.Z,rX,rY,rZ)
            elseif typeof(kf.Value)=="Vector3" then valStr=string.format("Vector3.new(%.4f,%.4f,%.4f)",kf.Value.X,kf.Value.Y,kf.Value.Z)
            elseif typeof(kf.Value)=="number" then valStr=string.format("%.4f",kf.Value) end
            table.insert(code,string.format("                {Time=%.4f,Value=%s},",kf.Time,valStr))
        end
        table.insert(code,"            },"); table.insert(code,"        },")
    end
    table.insert(code,"    },"); table.insert(code,"}")
    table.insert(code,""); table.insert(code,"local function Evaluate(track,time)")
    table.insert(code,"    local kfs=track.Keyframes; if #kfs==0 then return nil end"); table.insert(code,"    if time<=kfs[1].Time then return kfs[1].Value end"); table.insert(code,"    if time>=kfs[#kfs].Time then return kfs[#kfs].Value end")
    table.insert(code,"    for i=1,#kfs-1 do local a,b=kfs[i],kfs[i+1]; if time>=a.Time and time<=b.Time then")
    table.insert(code,"        local alpha=(time-a.Time)/(b.Time-a.Time)")
    table.insert(code,"        if typeof(a.Value)=='CFrame' then return a.Value:Lerp(b.Value,alpha)")
    table.insert(code,"        elseif typeof(a.Value)=='Vector3' then return a.Value:Lerp(b.Value,alpha)")
    table.insert(code,"        elseif typeof(a.Value)=='number' then return a.Value+(b.Value-a.Value)*alpha")
    table.insert(code,"        else return a.Value end"); table.insert(code,"    end end"); table.insert(code,"    return nil"); table.insert(code,"end")
    table.insert(code,""); table.insert(code,"local function ApplyMotor6D(rig,time)")
    table.insert(code,"    for trackName,track in pairs(ANIM_DATA.Tracks) do")
    table.insert(code,"        local val=Evaluate(track,time)")
    table.insert(code,"        if val and typeof(val)=='CFrame' then")
    table.insert(code,"            for _,obj in ipairs(rig:GetDescendants()) do")
    table.insert(code,"                if obj:IsA('Motor6D') and obj.Name==trackName then obj.Transform=val end")
    table.insert(code,"            end"); table.insert(code,"        end"); table.insert(code,"    end"); table.insert(code,"end")
    table.insert(code,""); table.insert(code,"local player=Players.LocalPlayer")
    table.insert(code,"local char=player.Character or player.CharacterAdded:Wait()")
    table.insert(code,"local playing=false; local animTime=0; local speed=1; local loop=true; local conn=nil")
    table.insert(code,""); table.insert(code,"function PlayAnim()")
    table.insert(code,"    if playing then return end; playing=true; local last=tick()")
    table.insert(code,"    conn=RunService.Heartbeat:Connect(function()")
    table.insert(code,"        local now=tick(); local dt=now-last; last=now")
    table.insert(code,"        if not playing then return end; animTime+=dt*speed")
    table.insert(code,"        if animTime>ANIM_DATA.Duration then if loop then animTime=0 else animTime=ANIM_DATA.Duration; PauseAnim() end end")
    table.insert(code,"        ApplyMotor6D(char,animTime)"); table.insert(code,"    end)"); table.insert(code,"end")
    table.insert(code,"function PauseAnim() playing=false; if conn then conn:Disconnect(); conn=nil end end")
    table.insert(code,"function StopAnim() PauseAnim(); animTime=0 end")
    table.insert(code,""); table.insert(code,string.format("-- Categoria: %s",proj.Category))
    if proj.Category=="idle" then table.insert(code,"PlayAnim() -- auto-play loop infinito")
    elseif proj.Category=="core" then table.insert(code,"-- Conecte com Humanoid.Running")
    elseif proj.Category=="movement" then table.insert(code,"-- Acione via InputBegan (Space=jump/vault)")
    elseif proj.Category=="actions" then table.insert(code,"loop=false -- one-shot")
    elseif proj.Category=="tool" then table.insert(code,"-- Conecte tool.Equipped/Activated") end
    table.insert(code,""); table.insert(code,"return {Play=PlayAnim,Pause=PauseAnim,Stop=StopAnim,Seek=function(t) animTime=math.clamp(t,0,ANIM_DATA.Duration) end,IsPlaying=function() return playing end}")
    return table.concat(code,"\n"),nil
end

-- =============================================================================
-- UI HELPERS MOBILE-FIRST
-- =============================================================================
local screen = Instance.new("ScreenGui")
screen.Name = "MoonAnimatorSupremo_UI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local function corner(inst,r) local c=Instance.new("UICorner"); c.CornerRadius=r or cfg.RADIUS; c.Parent=inst end
local function stroke(inst,col,th) local s=Instance.new("UIStroke"); s.Color=col or cfg.BORDER; s.Thickness=th or 1; s.Parent=inst end

-- Notification Host (topo, largura total)
local notifHost = Instance.new("Frame")
notifHost.Name = "Notifications"
notifHost.Size = UDim2.new(1, -20, 0, 120)
notifHost.Position = UDim2.new(0, 10, 0, 10)
notifHost.BackgroundTransparency = 1
notifHost.ZIndex = 999
notifHost.Parent = screen
local notifList = Instance.new("UIListLayout")
notifList.SortOrder = Enum.SortOrder.LayoutOrder
notifList.Padding = UDim.new(0, 8)
notifList.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifList.Parent = notifHost

function M.Notify(message, level)
    local color = cfg.ACCENT
    if level == "error" then color = Color3.fromRGB(255,60,80)
    elseif level == "warning" then color = cfg.ACCENT2
    elseif level == "success" then color = cfg.ACCENT_OK end
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 0, 0)
    toast.AutomaticSize = Enum.AutomaticSize.Y
    toast.BackgroundColor3 = cfg.SURFACE
    toast.LayoutOrder = tick()
    toast.Parent = notifHost
    corner(toast)
    stroke(toast, color, 2)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.Position = UDim2.new(0, 10, 0, 10)
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
    progress.Size = UDim2.new(1, 0, 0, 3)
    progress.Position = UDim2.new(0, 0, 1, -3)
    progress.BackgroundColor3 = color
    progress.BorderSizePixel = 0
    progress.Parent = toast
    task.spawn(function()
        local dur = 4; local st = tick()
        while tick() - st < dur do
            progress.Size = UDim2.new(1 - ((tick()-st)/dur), 0, 0, 3)
            task.wait(0.05)
        end
        toast:Destroy()
    end)
end

-- =============================================================================
-- MOBILE LAYOUT: PAGES + BOTTOM NAV
-- =============================================================================
local pages = Instance.new("Frame")
pages.Name = "Pages"
pages.Size = UDim2.new(1, 0, 1, -110)
pages.Position = UDim2.new(0, 0, 0, 50)
pages.BackgroundTransparency = 1
pages.Parent = screen

local pageContents = {}
local currentPage = "Scene"

local function createPage(name)
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = (name == currentPage)
    f.Parent = pages
    pageContents[name] = f
    return f
end

-- Bottom Nav Bar (mobile dock)
local navBar = Instance.new("Frame")
navBar.Name = "NavBar"
navBar.Size = UDim2.new(1, 0, 0, 60)
navBar.Position = UDim2.new(0, 0, 1, -60)
navBar.BackgroundColor3 = cfg.BG3
navBar.BorderSizePixel = 0
navBar.ZIndex = 100
navBar.Parent = screen
stroke(navBar)

local navList = Instance.new("UIListLayout")
navList.FillDirection = Enum.FillDirection.Horizontal
navList.SortOrder = Enum.SortOrder.LayoutOrder
navList.Padding = UDim.new(0, 4)
navList.HorizontalAlignment = Enum.HorizontalAlignment.Center
navList.VerticalAlignment = Enum.VerticalAlignment.Center
navList.Parent = navBar

local navButtons = {}
local function createNavButton(label, pageName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, math.min(100, viewportSize.X/5 - 6), 1, -8)
    btn.Position = UDim2.new(0, 0, 0, 4)
    btn.BackgroundColor3 = (pageName == currentPage) and cfg.SELECTED or cfg.SURFACE
    btn.Text = label
    btn.TextColor3 = (pageName == currentPage) and cfg.ACCENT or cfg.TEXT2
    btn.Font = cfg.FONT_BOLD
    btn.TextSize = cfg.TEXT_SMALL
    btn.BorderSizePixel = 0
    btn.ZIndex = 101
    btn.Parent = navBar
    corner(btn, UDim.new(0, 8))
    btn.Activated:Connect(function()
        currentPage = pageName
        for n, p in pairs(pageContents) do p.Visible = (n == pageName) end
        for _, b in pairs(navButtons) do
            b.BackgroundColor3 = (b:GetAttribute("Page") == pageName) and cfg.SELECTED or cfg.SURFACE
            b.TextColor3 = (b:GetAttribute("Page") == pageName) and cfg.ACCENT or cfg.TEXT2
        end
    end)
    btn:SetAttribute("Page", pageName)
    table.insert(navButtons, btn)
    return btn
end

createNavButton("🎬\nScene", "Scene")
createNavButton("⏱\nKeys", "Keys")
createNavButton("📈\nCurves", "Curves")
createNavButton("🦴\nRig", "Rig")
createNavButton("⚙️\nTools", "Tools")

-- =============================================================================
-- TOP MENU BAR (compacto)
-- =============================================================================
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 50)
topBar.BackgroundColor3 = cfg.BG3
topBar.BorderSizePixel = 0
topBar.ZIndex = 90
topBar.Parent = screen

local topTitle = Instance.new("TextLabel")
topTitle.Size = UDim2.new(0.6, 0, 1, 0)
topTitle.Position = UDim2.new(0, 10, 0, 0)
topTitle.BackgroundTransparency = 1
topTitle.Text = "🌙 Moon Animator"
topTitle.TextColor3 = cfg.ACCENT
topTitle.Font = cfg.FONT_BOLD
topTitle.TextSize = cfg.TEXT_SIZE + 2
topTitle.TextXAlignment = Enum.TextXAlignment.Left
topTitle.ZIndex = 91
topTitle.Parent = topBar

local menuBtn = Instance.new("TextButton")
menuBtn.Size = UDim2.new(0, 44, 0, 44)
menuBtn.Position = UDim2.new(1, -50, 0, 3)
menuBtn.BackgroundColor3 = cfg.SURFACE
menuBtn.Text = "☰"
menuBtn.TextColor3 = cfg.TEXT
menuBtn.Font = cfg.FONT_BOLD
menuBtn.TextSize = 20
menuBtn.BorderSizePixel = 0
menuBtn.ZIndex = 91
menuBtn.Parent = topBar
corner(menuBtn, UDim.new(0, 8))

-- Dropdown menu
local menuOpen = false
local menuFrame = Instance.new("Frame")
menuFrame.Size = UDim2.new(0, 220, 0, 0)
menuFrame.AutomaticSize = Enum.AutomaticSize.Y
menuFrame.Position = UDim2.new(1, -230, 0, 50)
menuFrame.BackgroundColor3 = cfg.BG2
menuFrame.BorderSizePixel = 0
menuFrame.ZIndex = 200
menuFrame.Visible = false
menuFrame.Parent = screen
corner(menuFrame)
stroke(menuFrame)

local menuList = Instance.new("UIListLayout")
menuList.SortOrder = Enum.SortOrder.LayoutOrder
menuList.Padding = UDim.new(0, 2)
menuList.Parent = menuFrame

local function addMenuItem(text, action)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 46)
    btn.Position = UDim2.new(0, 4, 0, 0)
    btn.BackgroundColor3 = cfg.SURFACE
    btn.Text = text
    btn.TextColor3 = cfg.TEXT2
    btn.Font = cfg.FONT_BOLD
    btn.TextSize = cfg.TEXT_SIZE
    btn.BorderSizePixel = 0
    btn.ZIndex = 201
    btn.Parent = menuFrame
    corner(btn, UDim.new(0, 6))
    btn.Activated:Connect(function()
        action()
        menuFrame.Visible = false
        menuOpen = false
    end)
    return btn
end

addMenuItem("📤 Export Animation", function() M.OpenExportOverlay() end)
addMenuItem("📥 Import JSON", function() M.OpenImportOverlay() end)
addMenuItem("💾 Save Project", function() M.Notify("Projeto salvo!", "success") end)
addMenuItem("📂 New Project", function() M.Notify("Novo projeto criado!", "success") end)

menuBtn.Activated:Connect(function()
    menuOpen = not menuOpen
    menuFrame.Visible = menuOpen
end)

-- =============================================================================
-- PLAYBACK BAR (Scene page bottom overlay)
-- =============================================================================
local scenePage = createPage("Scene")

local playBar = Instance.new("Frame")
playBar.Size = UDim2.new(1, -20, 0, 56)
playBar.Position = UDim2.new(0, 10, 1, -66)
playBar.BackgroundColor3 = cfg.BG3
playBar.BorderSizePixel = 0
playBar.ZIndex = 50
playBar.Parent = scenePage
corner(playBar, UDim.new(0, 12))
stroke(playBar)

local playBarList = Instance.new("UIListLayout")
playBarList.FillDirection = Enum.FillDirection.Horizontal
playBarList.SortOrder = Enum.SortOrder.LayoutOrder
playBarList.Padding = UDim.new(0, 6)
playBarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
playBarList.VerticalAlignment = Enum.VerticalAlignment.Center
playBarList.Parent = playBar

local function playBtn(text, col, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 56, 0, 48)
    btn.BackgroundColor3 = col or cfg.SURFACE
    btn.Text = text
    btn.TextColor3 = cfg.TEXT
    btn.Font = cfg.FONT_BOLD
    btn.TextSize = 18
    btn.BorderSizePixel = 0
    btn.ZIndex = 51
    btn.Parent = playBar
    corner(btn, UDim.new(0, 10))
    btn.Activated:Connect(onClick)
    return btn
end

playBtn("⏮", cfg.SURFACE, function() M.Playback:Stop() end)
playBtn("⏵", cfg.SELECTED, function()
    if M.Playback:IsPlaying() then M.Playback:Pause() else M.Playback:Play() end
end)
playBtn("⏹", cfg.SURFACE, function() M.Playback:Stop() end)
local timeDisplay = playBtn("0.00", cfg.BG, function() end)
timeDisplay.Size = UDim2.new(0, 80, 0, 48)
timeDisplay.TextColor3 = cfg.ACCENT

M.EventBus:Subscribe("Playback.TimeChanged", function(t)
    timeDisplay.Text = string.format("%.2f", t)
end)
M.EventBus:Subscribe("Playback.Seeked", function(t)
    timeDisplay.Text = string.format("%.2f", t)
end)

-- =============================================================================
-- VIEWPORT (Scene page)
-- =============================================================================
local viewportWrapper = Instance.new("Frame")
viewportWrapper.Size = UDim2.new(1, -20, 1, -76)
viewportWrapper.Position = UDim2.new(0, 10, 0, 10)
viewportWrapper.BackgroundColor3 = cfg.BG
viewportWrapper.BorderSizePixel = 0
viewportWrapper.ZIndex = 10
viewportWrapper.Parent = scenePage
corner(viewportWrapper)
stroke(viewportWrapper)

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
statsLbl.Size = UDim2.new(0, 160, 0, 50)
statsLbl.Position = UDim2.new(0, 8, 0, 8)
statsLbl.BackgroundColor3 = cfg.SURFACE
statsLbl.BackgroundTransparency = 0.3
statsLbl.Text = "FPS: --\nRig: --"
statsLbl.TextColor3 = cfg.TEXT2
statsLbl.Font = cfg.FONT_MONO
statsLbl.TextSize = 11
statsLbl.ZIndex = 15
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
    if not target then statsLbl.Text = "Rig: Não\nencontrado"; return end
    local clone = target:Clone()
    if clone.PrimaryPart then clone:SetPrimaryPartCFrame(CFrame.new(0, 0, 0)) end
    clone.Parent = viewport
    M._lastClonedRig = clone
    statsLbl.Text = string.format("Rig: %s\nParts: %d", target.Name, #clone:GetDescendants())
    M.Notify("Rig carregado!", "success")
    local lLeg = clone:FindFirstChild("LeftUpperLeg", true)
    local lKnee = clone:FindFirstChild("LeftLowerLeg", true)
    local lFoot = clone:FindFirstChild("LeftFoot", true)
    if lLeg and lKnee and lFoot then M.IKSystem:CreateChain("LeftLeg", {lLeg, lKnee, lFoot}, CFrame.new(0, 0, 5)) end
    local rLeg = clone:FindFirstChild("RightUpperLeg", true)
    local rKnee = clone:FindFirstChild("RightLowerLeg", true)
    local rFoot = clone:FindFirstChild("RightFoot", true)
    if rLeg and rKnee and rFoot then M.IKSystem:CreateChain("RightLeg", {rLeg, rKnee, rFoot}, CFrame.new(2, 0, 5)) end
end

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 110, 0, 40)
refreshBtn.Position = UDim2.new(1, -120, 0, 8)
refreshBtn.BackgroundColor3 = cfg.SELECTED
refreshBtn.Text = "🔄 Refresh"
refreshBtn.TextColor3 = cfg.TEXT
refreshBtn.Font = cfg.FONT_BOLD
refreshBtn.TextSize = cfg.TEXT_SIZE
refreshBtn.ZIndex = 15
refreshBtn.Parent = viewportWrapper
corner(refreshBtn, UDim.new(0, 8))
refreshBtn.Activated:Connect(M.RefreshViewport)

-- =============================================================================
-- TIMELINE PAGE (Fullscreen touch)
-- =============================================================================
local keysPage = createPage("Keys")

local tlFrame = Instance.new("Frame")
tlFrame.Size = UDim2.new(1, 0, 1, 0)
tlFrame.BackgroundColor3 = cfg.BG
tlFrame.BorderSizePixel = 0
tlFrame.Parent = keysPage

local tlRuler = Instance.new("Frame")
tlRuler.Size = UDim2.new(1, 0, 0, 32)
tlRuler.BackgroundColor3 = cfg.BG3
tlRuler.BorderSizePixel = 0
tlRuler.Parent = tlFrame

local tlArea = Instance.new("Frame")
tlArea.Size = UDim2.new(1, 0, 1, -32)
tlArea.Position = UDim2.new(0, 0, 0, 32)
tlArea.BackgroundColor3 = cfg.BG
tlArea.BorderSizePixel = 0
tlArea.ClipsDescendants = true
tlArea.Parent = tlFrame

local playhead = Instance.new("Frame")
playhead.Size = UDim2.new(0, 3, 1, 0)
playhead.BackgroundColor3 = cfg.PLAYHEAD
playhead.BorderSizePixel = 0
playhead.ZIndex = 50
playhead.Parent = tlArea

local zoom = 80
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
            tick.Size = UDim2.new(0, 1, 0, 10)
            tick.Position = UDim2.new(0, x, 0, 22)
            tick.BackgroundColor3 = cfg.DISABLED
            tick.BorderSizePixel = 0
            tick.Parent = tlRuler
            if math.abs(t % 1) < 0.01 then
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(0, 50, 0, 18)
                lbl.Position = UDim2.new(0, x - 25, 0, 0)
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
        row.Size = UDim2.new(1, 0, 0, 36)
        row.Position = UDim2.new(0, 0, 0, y)
        row.BackgroundColor3 = (y % 72 < 36) and Color3.fromRGB(18,18,24) or cfg.BG2
        row.BorderSizePixel = 0
        row.Parent = tlArea
        table.insert(trackRows, row)
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0, 120, 0, 36)
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
            kfFrame.Size = UDim2.new(0, 14, 0, 14)
            kfFrame.Position = UDim2.new(0, x - 7, 0.5, -7)
            kfFrame.BackgroundColor3 = kf.Color or cfg.KF_FILL
            kfFrame.BorderSizePixel = 0
            kfFrame.ZIndex = 10
            kfFrame.Parent = row
            corner(kfFrame, UDim.new(1, 0))
            kfFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingKf = true
                    input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingKf = false end end)
                end
            end)
            table.insert(kfFrames, kfFrame)
        end
        y += 36
    end
    playhead.Position = UDim2.new(0, timeToX(M.Playback:GetTime()) - 1, 0, 0)
end

-- Touch pan & pinch zoom for timeline
local touches = {}
local lastPinchDist = nil
tlArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        touches[input] = { pos = input.Position, last = input.Position }
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and touches[input] then
        touches[input].pos = input.Position
        local touchCount = 0
        local firstPos, secondPos
        for _, data in pairs(touches) do
            touchCount += 1
            if touchCount == 1 then firstPos = data.pos elseif touchCount == 2 then secondPos = data.pos end
        end
        if touchCount == 2 and firstPos and secondPos then
            local dist = math.sqrt((firstPos.X - secondPos.X)^2 + (firstPos.Y - secondPos.Y)^2)
            if lastPinchDist then
                local delta = dist - lastPinchDist
                zoom = math.clamp(zoom + delta * 0.5, 10, 2000)
                if currentProject then buildTimeline(currentProject) end
            end
            lastPinchDist = dist
        elseif touchCount == 1 and not draggingKf then
            for _, data in pairs(touches) do
                if data.last then
                    local dx = data.pos.X - data.last.X
                    offset = offset - dx / zoom
                    if currentProject then buildTimeline(currentProject) end
                end
                data.last = data.pos
            end
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        touches[input] = nil
        lastPinchDist = nil
    end
end)

-- Also mouse support for desktop testing
tlArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not draggingKf then
        local x = input.Position.X - tlArea.AbsolutePosition.X
        local t = snapT(xToTime(x))
        M.Playback:Seek(t)
        playhead.Position = UDim2.new(0, timeToX(t) - 1, 0, 0)
    end
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
        M.Constraints:UpdateAll()
        M.IKSystem:UpdateAll()
    end
    if M.CameraEditor.activePath then M.CameraEditor:ApplyToViewport(M.CameraEditor.activePath, t, viewport) end
end)
M.EventBus:Subscribe("Playback.Seeked", function(t) playhead.Position = UDim2.new(0, timeToX(t) - 1, 0, 0) end)

-- =============================================================================
-- GRAPH PAGE
-- =============================================================================
local curvesPage = createPage("Curves")

local graphCanvas = Instance.new("Frame")
graphCanvas.Size = UDim2.new(1, 0, 1, 0)
graphCanvas.BackgroundColor3 = cfg.BG
graphCanvas.BorderSizePixel = 0
graphCanvas.Parent = curvesPage

local gZoomX, gZoomY, gPanX, gPanY = 80, 80, 0, 0
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
                seg.Size = UDim2.new(0, dist, 0, 3)
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
            dot.Size = UDim2.new(0, 12, 0, 12)
            dot.Position = UDim2.new(0, x-6, 0, y-6)
            dot.BackgroundColor3 = ch.Color
            dot.BorderSizePixel = 0
            dot.Parent = graphCanvas
            corner(dot, UDim.new(1, 0))
        end
    end
end

-- Touch for graph
local gTouches = {}
local lastGPinch = nil
graphCanvas.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then gTouches[input] = { pos = input.Position, last = input.Position } end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and gTouches[input] then
        gTouches[input].pos = input.Position
        local tCount = 0
        local fp, sp
        for _, data in pairs(gTouches) do tCount += 1; if tCount == 1 then fp = data.pos elseif tCount == 2 then sp = data.pos end end
        if tCount == 2 and fp and sp then
            local dist = math.sqrt((fp.X-sp.X)^2 + (fp.Y-sp.Y)^2)
            if lastGPinch then
                local d = dist - lastGPinch
                gZoomX = math.clamp(gZoomX + d*0.5, 10, 1000)
                gZoomY = math.clamp(gZoomY + d*0.5, 10, 1000)
                buildGraph()
            end
            lastGPinch = dist
        elseif tCount == 1 then
            for _, data in pairs(gTouches) do
                if data.last then
                    gPanX += (data.pos.X - data.last.X) / gZoomX
                    gPanY -= (data.pos.Y - data.last.Y) / gZoomY
                    buildGraph()
                end
                data.last = data.pos
            end
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then gTouches[input] = nil; lastGPinch = nil end
end)
graphCanvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(buildGraph)

-- =============================================================================
-- RIG PAGE (Outliner + Inspector combined for mobile)
-- =============================================================================
local rigPage = createPage("Rig")

local rigScroll = Instance.new("ScrollingFrame")
rigScroll.Size = UDim2.new(1, 0, 0.55, 0)
rigScroll.BackgroundColor3 = cfg.BG2
rigScroll.BorderSizePixel = 0
rigScroll.ScrollBarThickness = 6
rigScroll.ScrollBarImageColor3 = cfg.SURFACE_HL
rigScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
rigScroll.Parent = rigPage

local rigList = Instance.new("UIListLayout")
rigList.SortOrder = Enum.SortOrder.LayoutOrder
rigList.Padding = UDim.new(0, 2)
rigList.Parent = rigScroll

local inspectorPanel = Instance.new("Frame")
inspectorPanel.Name = "InspectorPanel"
inspectorPanel.Size = UDim2.new(1, 0, 0.45, 0)
inspectorPanel.Position = UDim2.new(0, 0, 0.55, 0)
inspectorPanel.BackgroundColor3 = cfg.BG3
inspectorPanel.BorderSizePixel = 0
inspectorPanel.Parent = rigPage

local inspTitle = Instance.new("TextLabel")
inspTitle.Size = UDim2.new(1, 0, 0, 32)
inspTitle.BackgroundColor3 = cfg.SURFACE
inspTitle.BorderSizePixel = 0
inspTitle.Text = " Inspector (toque um bone)"
inspTitle.TextColor3 = cfg.TEXT
inspTitle.Font = cfg.FONT_BOLD
inspTitle.TextSize = cfg.TEXT_SIZE
inspTitle.TextXAlignment = Enum.TextXAlignment.Left
inspTitle.Parent = inspectorPanel

local inspScroll = Instance.new("ScrollingFrame")
inspScroll.Size = UDim2.new(1, 0, 1, -32)
inspScroll.Position = UDim2.new(0, 0, 0, 32)
inspScroll.BackgroundColor3 = cfg.BG3
inspScroll.BorderSizePixel = 0
inspScroll.ScrollBarThickness = 4
inspScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
inspScroll.Parent = inspectorPanel
local inspListLay = Instance.new("UIListLayout")
inspListLay.SortOrder = Enum.SortOrder.LayoutOrder
inspListLay.Padding = UDim.new(0, 2)
inspListLay.Parent = inspScroll

local selectedNodes = {}
local nodeFrames = {}
local function refreshHierarchy()
    for _, c in ipairs(rigScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    nodeFrames = {}; selectedNodes = {}
    local function makeRow(name, depth)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -8, 0, 44)
        row.BackgroundColor3 = cfg.BG2
        row.Text = string.rep("  ", depth) .. name
        row.TextColor3 = cfg.TEXT2
        row.Font = cfg.FONT
        row.TextSize = cfg.TEXT_SIZE
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.BorderSizePixel = 0
        row.LayoutOrder = #rigScroll:GetChildren()
        row.Parent = rigScroll
        corner(row, UDim.new(0, 6))
        row.Activated:Connect(function()
            for _, c2 in ipairs(inspScroll:GetChildren()) do if c2:IsA("Frame") then c2:Destroy() end end
            local function addProp(n, v)
                local r = Instance.new("Frame")
                r.Size = UDim2.new(1, -8, 0, 40)
                r.BackgroundColor3 = cfg.SURFACE
                r.BorderSizePixel = 0
                r.LayoutOrder = #inspScroll:GetChildren()
                r.Parent = inspScroll
                corner(r, UDim.new(0, 4))
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(0.45, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = n
                lbl.TextColor3 = cfg.TEXT2
                lbl.Font = cfg.FONT
                lbl.TextSize = cfg.TEXT_SMALL
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = r
                local box = Instance.new("TextBox")
                box.Size = UDim2.new(0.55, -6, 0, 32)
                box.Position = UDim2.new(0.45, 2, 0.5, -16)
                box.BackgroundColor3 = cfg.BG2
                box.Text = v
                box.TextColor3 = cfg.TEXT
                box.Font = cfg.FONT_MONO
                box.TextSize = cfg.TEXT_SMALL
                box.ClearTextOnFocus = false
                box.BorderSizePixel = 0
                box.Parent = r
                corner(box, UDim.new(0, 4))
            end
            addProp("Name", name)
            addProp("Position", "0, 0, 0")
            addProp("Rotation", "0, 0, 0")
            addProp("Scale", "1, 1, 1")
            addProp("IK Weight", "1.0")
            addProp("Locked", "OFF")
            inspTitle.Text = " Inspector: " .. name
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
-- TOOLS PAGE (Grid de botões grandes)
-- =============================================================================
local toolsPage = createPage("Tools")

local toolsGrid = Instance.new("UIGridLayout")
toolsGrid.CellSize = UDim2.new(0, math.min(160, viewportSize.X/2 - 12), 0, 80)
toolsGrid.CellPadding = UDim.new(0, 10)
toolsGrid.FillDirection = Enum.FillDirection.Horizontal
toolsGrid.SortOrder = Enum.SortOrder.LayoutOrder
toolsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
toolsGrid.VerticalAlignment = Enum.VerticalAlignment.Top
toolsGrid.Parent = toolsPage

local toolsPad = Instance.new("UIPadding")
toolsPad.PaddingTop = UDim.new(0, 10)
toolsPad.PaddingLeft = UDim.new(0, 10)
toolsPad.PaddingRight = UDim.new(0, 10)
toolsPad.Parent = toolsPage

local function toolBtn(label, desc, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = color or cfg.SURFACE
    btn.Text = label .. "\n" .. (desc or "")
    btn.TextColor3 = cfg.TEXT
    btn.Font = cfg.FONT_BOLD
    btn.TextSize = 14
    btn.TextWrapped = true
    btn.BorderSizePixel = 0
    btn.Parent = toolsPage
    corner(btn, UDim.new(0, 10))
    btn.Activated:Connect(onClick)
    return btn
end

toolBtn("🦴 IK / FK", "Editar chains IK", cfg.SELECTED, function() M.OpenOverlay("IK") end)
toolBtn("⛓ Constraints", "Aim/Parent/Copy", cfg.ACCENT2, function() M.OpenOverlay("Constraints") end)
toolBtn("🤖 Auto-Rig", "Detectar R6/R15", cfg.ACCENT_OK, function() M.OpenOverlay("AutoRig") end)
toolBtn("😊 Facial", "Emoções / LipSync", Color3.fromRGB(255,120,180), function() M.OpenOverlay("Facial") end)
toolBtn("🧠 State Machine", "Nodes visuais", cfg.ACCENT, function() M.OpenOverlay("StateMachine") end)
toolBtn("🎥 Camera", "Cinematic paths", Color3.fromRGB(180,180,255), function() M.OpenOverlay("Camera") end)
toolBtn("📤 Export", "Gerar LocalScript", cfg.ACCENT_OK, function() M.OpenOverlay("Export") end)
toolBtn("📥 Import", "JSON para projeto", cfg.SURFACE_HL, function() M.OpenOverlay("Import") end)
toolBtn("⚡ LOD", "Performance", Color3.fromRGB(255,180,0), function() M.OpenOverlay("LOD") end)
toolBtn("🤖 AI Match", "Motion Matching", cfg.ACCENT2, function() M.OpenOverlay("AI") end)
toolBtn("👥 Collab", "Multiplayer", Color3.fromRGB(100,200,255), function() M.OpenOverlay("Collab") end)
toolBtn("ℹ️ Sobre", "v"..cfg.VERSION, cfg.BG3, function() M.Notify(cfg.NAME.." v"..cfg.VERSION.." | Moon Animator Supremo", "success") end)

-- =============================================================================
-- OVERLAY SYSTEM (fullscreen editors for mobile)
-- =============================================================================
local overlays = {}
local overlayHost = Instance.new("Frame")
overlayHost.Name = "Overlays"
overlayHost.Size = UDim2.new(1, 0, 1, 0)
overlayHost.BackgroundTransparency = 1
overlayHost.ZIndex = 300
overlayHost.Parent = screen

local function closeOverlay(name)
    if overlays[name] then overlays[name].Visible = false end
end

local function createOverlay(name, title)
    local f = Instance.new("Frame")
    f.Name = name.."Overlay"
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundColor3 = cfg.BG
    f.BorderSizePixel = 0
    f.ZIndex = 301
    f.Visible = false
    f.Parent = overlayHost
    overlays[name] = f
    
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 56)
    header.BackgroundColor3 = cfg.BG3
    header.BorderSizePixel = 0
    header.ZIndex = 302
    header.Parent = f
    
    local back = Instance.new("TextButton")
    back.Size = UDim2.new(0, 80, 0, 44)
    back.Position = UDim2.new(0, 8, 0, 6)
    back.BackgroundColor3 = cfg.SURFACE
    back.Text = "← Voltar"
    back.TextColor3 = cfg.TEXT
    back.Font = cfg.FONT_BOLD
    back.TextSize = cfg.TEXT_SIZE
    back.BorderSizePixel = 0
    back.ZIndex = 303
    back.Parent = header
    corner(back, UDim.new(0, 8))
    back.Activated:Connect(function() closeOverlay(name) end)
    
    local ttl = Instance.new("TextLabel")
    ttl.Size = UDim2.new(1, -100, 1, 0)
    ttl.Position = UDim2.new(0, 96, 0, 0)
    ttl.BackgroundTransparency = 1
    ttl.Text = title
    ttl.TextColor3 = cfg.ACCENT
    ttl.Font = cfg.FONT_BOLD
    ttl.TextSize = cfg.TEXT_SIZE + 2
    ttl.TextXAlignment = Enum.TextXAlignment.Left
    ttl.ZIndex = 303
    ttl.Parent = header
    
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, -56)
    content.Position = UDim2.new(0, 0, 0, 56)
    content.BackgroundTransparency = 1
    content.ZIndex = 302
    content.Parent = f
    
    return content
end

function M.OpenOverlay(which)
    for _, o in pairs(overlays) do o.Visible = false end
    if overlays[which] then overlays[which].Visible = true end
end

-- Export Overlay
local exportContent = createOverlay("Export", "📤 Export Animation")
local exportCatLbl = Instance.new("TextLabel")
exportCatLbl.Size = UDim2.new(1, -20, 0, 24)
exportCatLbl.Position = UDim2.new(0, 10, 0, 8)
exportCatLbl.BackgroundTransparency = 1
exportCatLbl.Text = "Categoria: idle | Cole como LOCALSCRIPT"
exportCatLbl.TextColor3 = cfg.ACCENT
exportCatLbl.Font = cfg.FONT
exportCatLbl.TextSize = cfg.TEXT_SMALL
exportCatLbl.TextXAlignment = Enum.TextXAlignment.Left
exportCatLbl.ZIndex = 303
exportCatLbl.Parent = exportContent

local exportScroll = Instance.new("ScrollingFrame")
exportScroll.Size = UDim2.new(1, -20, 1, -110)
exportScroll.Position = UDim2.new(0, 10, 0, 36)
exportScroll.BackgroundColor3 = cfg.BG2
exportScroll.BorderSizePixel = 0
exportScroll.ScrollBarThickness = 6
exportScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
exportScroll.ZIndex = 303
exportScroll.Parent = exportContent
corner(exportScroll)

local exportBox = Instance.new("TextBox")
exportBox.Size = UDim2.new(1, -12, 0, 0)
exportBox.AutomaticSize = Enum.AutomaticSize.Y
exportBox.Position = UDim2.new(0, 6, 0, 6)
exportBox.BackgroundTransparency = 1
exportBox.Text = "-- Exporte primeiro"
exportBox.TextColor3 = cfg.TEXT2
exportBox.Font = cfg.FONT_MONO
exportBox.TextSize = 11
exportBox.TextWrapped = true
exportBox.ClearTextOnFocus = false
exportBox.MultiLine = true
exportBox.ZIndex = 304
exportBox.Parent = exportScroll

local exportBtnRow = Instance.new("Frame")
exportBtnRow.Size = UDim2.new(1, -20, 0, 48)
exportBtnRow.Position = UDim2.new(0, 10, 1, -56)
exportBtnRow.BackgroundTransparency = 1
exportBtnRow.ZIndex = 303
exportBtnRow.Parent = exportContent

local function overlayBtn(parent, text, x, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 1, 0)
    btn.Position = UDim2.new(0, x, 0, 0)
    btn.BackgroundColor3 = color or cfg.SURFACE
    btn.Text = text
    btn.TextColor3 = cfg.TEXT
    btn.Font = cfg.FONT_BOLD
    btn.TextSize = cfg.TEXT_SIZE
    btn.BorderSizePixel = 0
    btn.ZIndex = 304
    btn.Parent = parent
    corner(btn, UDim.new(0, 6))
    btn.Activated:Connect(onClick)
    return btn
end

overlayBtn(exportBtnRow, "🔄 Gerar", 0, cfg.SELECTED, function()
    local code = M.ExportAnimation("proj_001", "Character")
    if code then exportBox.Text = code; M.Notify("Código gerado!", "success") end
end)
overlayBtn(exportBtnRow, "📋 Sel. Tudo", 130, cfg.ACCENT2, function()
    exportBox:CaptureFocus(); exportBox.CursorPosition = #exportBox.Text + 1
    M.Notify("Texto selecionado! (long-press para copiar)", "success")
end)
overlayBtn(exportBtnRow, "💾 Memória", 260, cfg.SURFACE_HL, function()
    M.FileSystem:Write("export/proj_001.lua", exportBox.Text)
    M.Notify("Salvo na memória!", "success")
end)

-- IK Overlay
local ikContent = createOverlay("IK", "🦴 IK / FK Editor")
local ikList = Instance.new("ScrollingFrame")
ikList.Size = UDim2.new(1, -20, 1, -60)
ikList.Position = UDim2.new(0, 10, 0, 10)
ikList.BackgroundColor3 = cfg.BG2
ikList.BorderSizePixel = 0
ikList.ScrollBarThickness = 6
ikList.AutomaticCanvasSize = Enum.AutomaticSize.Y
ikList.ZIndex = 303
ikList.Parent = ikContent
corner(ikList)

local function refreshIKList()
    for _, c in ipairs(ikList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for name, chain in pairs(M.IKSystem.chains) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 52)
        row.Position = UDim2.new(0, 4, 0, (#ikList:GetChildren()-1)*56)
        row.BackgroundColor3 = cfg.SURFACE
        row.BorderSizePixel = 0
        row.ZIndex = 304
        row.Parent = ikList
        corner(row)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name .. "\n(" .. #chain.Joints .. " joints)"
        lbl.TextColor3 = cfg.TEXT
        lbl.Font = cfg.FONT
        lbl.TextSize = cfg.TEXT_SMALL
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 305
        lbl.Parent = row
        local tg = Instance.new("TextButton")
        tg.Size = UDim2.new(0, 70, 0, 40)
        tg.Position = UDim2.new(1, -80, 0.5, -20)
        tg.BackgroundColor3 = chain.Enabled and cfg.ACCENT_OK or cfg.PLAYHEAD
        tg.Text = chain.Enabled and "ON" or "OFF"
        tg.TextColor3 = cfg.TEXT
        tg.Font = cfg.FONT_BOLD
        tg.TextSize = cfg.TEXT_SIZE
        tg.BorderSizePixel = 0
        tg.ZIndex = 305
        tg.Parent = row
        corner(tg, UDim.new(0, 6))
        tg.Activated:Connect(function()
            chain.Enabled = not chain.Enabled
            tg.BackgroundColor3 = chain.Enabled and cfg.ACCENT_OK or cfg.PLAYHEAD
            tg.Text = chain.Enabled and "ON" or "OFF"
            M.Notify(name .. " IK " .. (chain.Enabled and "ativado" or "desativado"), chain.Enabled and "success" or "warning")
        end)
    end
end

local solveAllBtn = Instance.new("TextButton")
solveAllBtn.Size = UDim2.new(0, 160, 0, 44)
solveAllBtn.Position = UDim2.new(0.5, -80, 1, -52)
solveAllBtn.BackgroundColor3 = cfg.SELECTED
solveAllBtn.Text = "🦴 Solve All IK"
solveAllBtn.TextColor3 = cfg.TEXT
solveAllBtn.Font = cfg.FONT_BOLD
solveAllBtn.TextSize = cfg.TEXT_SIZE
solveAllBtn.BorderSizePixel = 0
solveAllBtn.ZIndex = 303
solveAllBtn.Parent = ikContent
corner(solveAllBtn, UDim.new(0, 8))
solveAllBtn.Activated:Connect(function()
    M.IKSystem:UpdateAll(); M.Notify("IK resolvido!", "success")
end)

overlays["IK"]:GetPropertyChangedSignal("Visible"):Connect(function() if overlays["IK"].Visible then refreshIKList() end end)

-- Constraints Overlay
local consContent = createOverlay("Constraints", "⛓ Constraints")
local consList = Instance.new("ScrollingFrame")
consList.Size = UDim2.new(1, -20, 1, -60)
consList.Position = UDim2.new(0, 10, 0, 10)
consList.BackgroundColor3 = cfg.BG2
consList.BorderSizePixel = 0
consList.ScrollBarThickness = 6
consList.AutomaticCanvasSize = Enum.AutomaticSize.Y
consList.ZIndex = 303
consList.Parent = consContent
corner(consList)

local function refreshConsList()
    for _, c in ipairs(consList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for i, c in ipairs(M.Constraints.list) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 48)
        row.Position = UDim2.new(0, 4, 0, (i-1)*52)
        row.BackgroundColor3 = cfg.SURFACE
        row.BorderSizePixel = 0
        row.ZIndex = 304
        row.Parent = consList
        corner(row)
        local src = c.Source and c.Source.Name or "None"
        local tgt = c.Target and c.Target.Name or "None"
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = c.Type .. "\n" .. src .. " → " .. tgt
        lbl.TextColor3 = cfg.TEXT2
        lbl.Font = cfg.FONT
        lbl.TextSize = cfg.TEXT_SMALL
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 305
        lbl.Parent = row
        local del = Instance.new("TextButton")
        del.Size = UDim2.new(0, 60, 0, 36)
        del.Position = UDim2.new(1, -68, 0.5, -18)
        del.BackgroundColor3 = cfg.PLAYHEAD
        del.Text = "×"
        del.TextColor3 = cfg.TEXT
        del.Font = cfg.FONT_BOLD
        del.TextSize = 20
        del.BorderSizePixel = 0
        del.ZIndex = 305
        del.Parent = row
        corner(del, UDim.new(0, 6))
        del.Activated:Connect(function()
            table.remove(M.Constraints.list, i); refreshConsList(); M.Notify("Constraint removida", "warning")
        end)
    end
end
overlays["Constraints"]:GetPropertyChangedSignal("Visible"):Connect(function() if overlays["Constraints"].Visible then refreshConsList() end end)

-- AutoRig Overlay
local arContent = createOverlay("AutoRig", "🤖 Auto-Rig")
overlayBtn(arContent, "🔍 Analisar Workspace", 10, cfg.SELECTED, function()
    local rigType, bones = M.AutoRig:Analyze(workspace)
    M.Notify("Rig: " .. rigType .. " (" .. #bones .. " parts)", "success")
end)
overlayBtn(arContent, "🦴 Aplicar R15", 10, cfg.ACCENT_OK, function()
    local tpl = M.AutoRig:BuildTemplate(workspace, "R15")
    M.Notify("Auto-Rig R15: " .. #tpl .. " bones mapeados!", "success")
end)

-- Facial Overlay
local faceContent = createOverlay("Facial", "😊 Facial System")
overlayBtn(faceContent, "Neutral", 10, cfg.SURFACE, function() M.FacialSystem:SetEmotion("Neutral", M._lastClonedRig) end)
overlayBtn(faceContent, "Happy", 140, cfg.ACCENT_OK, function() M.FacialSystem:SetEmotion("Happy", M._lastClonedRig) end)
overlayBtn(faceContent, "Sad", 270, cfg.ACCENT, function() M.FacialSystem:SetEmotion("Sad", M._lastClonedRig) end)
overlayBtn(faceContent, "Angry", 10, cfg.PLAYHEAD, function() M.FacialSystem:SetEmotion("Angry", M._lastClonedRig) end)
overlayBtn(faceContent, "Surprised", 140, cfg.ACCENT2, function() M.FacialSystem:SetEmotion("Surprised", M._lastClonedRig) end)
overlayBtn(faceContent, "👁 Eye Track", 10, cfg.SELECTED, function() M.FacialSystem:SetEyeTarget(Vector3.new(0,5,0), M._lastClonedRig); M.Notify("Eye tracking!", "success") end)
overlayBtn(faceContent, "👄 LipSync 'A'", 140, Color3.fromRGB(255,120,180), function() M.FacialSystem:LipSync("A", M._lastClonedRig); M.Notify("LipSync A!", "success") end)

-- State Machine Overlay
local smContent = createOverlay("StateMachine", "🧠 State Machine")
local smCanvas = Instance.new("Frame")
smCanvas.Size = UDim2.new(1, 0, 1, 0)
smCanvas.BackgroundColor3 = cfg.BG
smCanvas.BorderSizePixel = 0
smCanvas.ZIndex = 303
smCanvas.Parent = smContent

local sm = M.StateMachine:Create("sm_001", "Locomotion")
M.StateMachine:AddState("sm_001", {Id="Idle", Name="Idle", Pos={x=50,y=100}, AnimationTrack="idle"})
M.StateMachine:AddState("sm_001", {Id="Walk", Name="Walk", Pos={x=200,y=100}, AnimationTrack="walk"})
M.StateMachine:AddState("sm_001", {Id="Run", Name="Run", Pos={x=350,y=100}, AnimationTrack="run"})
M.StateMachine:AddTransition("sm_001", {Id="T1", From="Idle", To="Walk", Condition="Speed>0.1"})
M.StateMachine:AddTransition("sm_001", {Id="T2", From="Walk", To="Run", Condition="Speed>12"})

for _, s in ipairs(sm.States) do
    local node = Instance.new("TextButton")
    node.Size = UDim2.new(0, 100, 0, 56)
    node.Position = UDim2.new(0, s.Pos.x, 0, s.Pos.y)
    node.BackgroundColor3 = cfg.SURFACE
    node.Text = s.Name
    node.TextColor3 = cfg.TEXT
    node.Font = cfg.FONT_BOLD
    node.TextSize = cfg.TEXT_SIZE
    node.BorderSizePixel = 0
    node.ZIndex = 304
    node.Parent = smCanvas
    corner(node, UDim.new(0, 8))
    local ndrag = false; local nstart = Vector2.zero; local npos = UDim2.new()
    node.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ndrag = true; nstart = Vector2.new(input.Position.X, input.Position.Y); npos = node.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then ndrag = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if ndrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = Vector2.new(input.Position.X, input.Position.Y) - nstart
            node.Position = UDim2.new(0, npos.X.Offset + d.X, 0, npos.Y.Offset + d.Y)
        end
    end)
end

-- Camera Overlay
local camContent = createOverlay("Camera", "🎥 Camera Editor")
local path = M.CameraEditor:CreatePath("Cinematic_01")
M.CameraEditor:AddKeyframe("Cinematic_01", 0, CFrame.new(10,8,10)*CFrame.Angles(0,math.rad(45),0), 60, 0, 0)
M.CameraEditor:AddKeyframe("Cinematic_01", 2, CFrame.new(5,6,5)*CFrame.Angles(0,math.rad(90),0), 50, 0.2, 5)
M.CameraEditor:AddKeyframe("Cinematic_01", 5, CFrame.new(0,4,0)*CFrame.Angles(0,math.rad(180),0), 40, 0, 10)

for i, kf in ipairs(path.Keyframes) do
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -16, 0, 48)
    row.Position = UDim2.new(0, 8, 0, (i-1)*54)
    row.BackgroundColor3 = cfg.SURFACE
    row.Text = string.format("%.1fs | FOV:%.0f | Shake:%.1f | DOF:%.0f", kf.Time, kf.FOV, kf.ShakeAmp, kf.DOFDist)
    row.TextColor3 = cfg.TEXT2
    row.Font = cfg.FONT
    row.TextSize = cfg.TEXT_SMALL
    row.BorderSizePixel = 0
    row.ZIndex = 304
    row.Parent = camContent
    corner(row, UDim.new(0, 6))
end
overlayBtn(camContent, "▶ Preview na Viewport", 10, cfg.SELECTED, function()
    M.CameraEditor.activePath = "Cinematic_01"
    M.Notify("Camera path ativo na viewport!", "success")
end)

-- Import Overlay
local impContent = createOverlay("Import", "📥 Import JSON")
local impBox = Instance.new("TextBox")
impBox.Size = UDim2.new(1, -20, 0, 200)
impBox.Position = UDim2.new(0, 10, 0, 10)
impBox.BackgroundColor3 = cfg.BG2
impBox.Text = '{"Name":"Test","Category":"idle","Duration":2,"Tracks":[]}'
impBox.TextColor3 = cfg.TEXT2
impBox.Font = cfg.FONT_MONO
impBox.TextSize = 11
impBox.TextWrapped = true
impBox.ClearTextOnFocus = false
impBox.MultiLine = true
impBox.ZIndex = 304
impBox.Parent = impContent
corner(impBox)
overlayBtn(impContent, "📥 Importar", 10, cfg.ACCENT_OK, function()
    M.Importer:FromJSON(impBox.Text, "imported_" .. tostring(tick()))
end)

-- LOD Overlay
local lodContent = createOverlay("LOD", "⚡ LOD & Performance")
for i, lvl in ipairs(M.LODSystem.levels) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -16, 0, 48)
    row.Position = UDim2.new(0, 8, 0, (i-1)*54)
    row.BackgroundColor3 = cfg.SURFACE
    row.BorderSizePixel = 0
    row.ZIndex = 304
    row.Parent = lodContent
    corner(row)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.format("> %dm: Skip %d frames | Max %d bones", lvl.dist, lvl.skip, lvl.bones)
    lbl.TextColor3 = cfg.TEXT2
    lbl.Font = cfg.FONT
    lbl.TextSize = cfg.TEXT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 305
    lbl.Parent = row
end
overlayBtn(lodContent, "🧪 Testar LOD (80m)", 10, cfg.SELECTED, function()
    local lvl = M.LODSystem:GetLevel(80)
    M.Notify(string.format("LOD 80m: Skip=%d, Bones=%d", lvl.skip, lvl.bones), "success")
end)

-- AI Overlay
local aiContent = createOverlay("AI", "🤖 Motion Matching")
overlayBtn(aiContent, "🔍 Match Pose", 10, cfg.ACCENT2, function()
    local match = M.MotionMatching:FindBestMatch({Root=Vector3.new(0,0,0)}, Vector3.new(10,0,0))
    if match then M.Notify("Match: " .. match.AnimId .. " @ " .. string.format("%.2f", match.Time), "success")
    else M.Notify("Sem poses na database.", "warning") end
end)
overlayBtn(aiContent, "💡 Suggest", 140, cfg.SELECTED, function()
    local sug = M.MotionMatching:SuggestTransition("idle", {"walk","run"})
    if sug then M.Notify("Sugestão: " .. sug.AnimId, "success") end
end)

-- Collab Overlay
local colContent = createOverlay("Collab", "👥 Collaboration")
overlayBtn(colContent, "🏠 Host Session", 10, cfg.ACCENT_OK, function() M.Collaboration:Host("Session_" .. tostring(math.random(1000,9999))) end)
local joinBox = Instance.new("TextBox")
joinBox.Size = UDim2.new(0, 160, 0, 40)
joinBox.Position = UDim2.new(0, 10, 0, 60)
joinBox.BackgroundColor3 = cfg.BG2
joinBox.Text = "Session_ID"
joinBox.TextColor3 = cfg.TEXT2
joinBox.Font = cfg.FONT
joinBox.TextSize = cfg.TEXT_SIZE
joinBox.BorderSizePixel = 0
joinBox.ZIndex = 304
joinBox.Parent = colContent
corner(joinBox)
overlayBtn(colContent, "🔗 Join", 180, cfg.SELECTED, function() M.Collaboration:Join(joinBox.Text) end)

-- =============================================================================
-- DEMO PROJECT
-- =============================================================================
local project = M.AnimationData:CreateProject("proj_001", "Supremo Mobile", "idle")
project.FPS = 60; project.Duration = 5
M.AnimationData:AddTrack(project.Id, {Id="HumanoidRootPart", Name="Root", Type="CFrame", TargetPath="Workspace.Rig.HumanoidRootPart",
    Keyframes = {{Time=0, Value=CFrame.new(0,0,0), Color=cfg.ACCENT}, {Time=2, Value=CFrame.new(5,2,0), Color=cfg.ACCENT}, {Time=5, Value=CFrame.new(0,0,5), Color=cfg.ACCENT}}})
M.AnimationData:AddTrack(project.Id, {Id="Head", Name="Head", Type="Rotation", TargetPath="Workspace.Rig.Head",
    Keyframes = {{Time=0, Value=CFrame.Angles(0,0,0), Color=cfg.ACCENT2}, {Time=2.5, Value=CFrame.Angles(0,math.rad(45),0), Color=cfg.ACCENT2}, {Time=5, Value=CFrame.Angles(0,0,0), Color=cfg.ACCENT2}}})

M.Playback:SetProject(project.Id)
buildTimeline(project)
buildGraph()
M.RefreshViewport()

-- =============================================================================
-- FINAL
-- =============================================================================
M.Notify(string.format("%s v%s", cfg.NAME, cfg.VERSION), "success")
M.Notify("5 abas na parte inferior. Toque para navegar.", "success")
M.Notify("Timeline: 1 dedo = pan, 2 dedos = pinch zoom", "success")
M.Notify("Tools > abre todos os editores em tela cheia", "success")

getfenv()["MoonAnimator"] = M
