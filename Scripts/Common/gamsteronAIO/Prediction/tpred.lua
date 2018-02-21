
-- http://gamingonsteroids.com/user/198940-trus/
local mathSqrt = math.sqrt
class "__gsoTPred"

function __gsoTPred:CutWaypoints(Waypoints, distance, unit)
    local result = {}
    local remaining = distance
    if distance > 0 then
        for i = 1, #Waypoints -1 do
            local A, B = Waypoints[i], Waypoints[i + 1]
            if A and B then 
                local dist = self:GetDistance(A, B)
                if dist >= remaining then
                    result[1] = Vector(A) + remaining * (Vector(B) - Vector(A)):Normalized()

                    for j = i + 1, #Waypoints do
                        result[j - i + 1] = Waypoints[j]
                    end
                    remaining = 0
                    break
                else
                    remaining = remaining - dist
                end
            end
        end
    else
        local A, B = Waypoints[1], Waypoints[2]
        result = Waypoints
        result[1] = Vector(A) - distance * (Vector(B) - Vector(A)):Normalized()
    end
    return result
end

function __gsoTPred:VectorMovementCollision(startPoint1, endPoint1, v1, startPoint2, v2, delay)
    local sP1x, sP1y, eP1x, eP1y, sP2x, sP2y = startPoint1.x, startPoint1.z, endPoint1.x, endPoint1.z, startPoint2.x, startPoint2.z
    local d, e = eP1x-sP1x, eP1y-sP1y
    local dist, t1, t2 = mathSqrt(d*d+e*e), nil, nil
    local S, K = dist~=0 and v1*d/dist or 0, dist~=0 and v1*e/dist or 0
    local function GetCollisionPoint(t) return t and {x = sP1x+S*t, y = sP1y+K*t} or nil end
    if delay and delay~=0 then sP1x, sP1y = sP1x+S*delay, sP1y+K*delay end
    local r, j = sP2x-sP1x, sP2y-sP1y
    local c = r*r+j*j
    if dist>0 then
        if v1 == math.huge then
            local t = dist/v1
            t1 = v2*t>=0 and t or nil
        elseif v2 == math.huge then
            t1 = 0
        else
            local a, b = S*S+K*K-v2*v2, -r*S-j*K
            if a==0 then 
                if b==0 then --c=0->t variable
                    t1 = c==0 and 0 or nil
                else --2*b*t+c=0
                    local t = -c/(2*b)
                    t1 = v2*t>=0 and t or nil
                end
            else --a*t*t+2*b*t+c=0
                local sqr = b*b-a*c
                if sqr>=0 then
                    local nom = mathSqrt(sqr)
                    local t = (-nom-b)/a
                    t1 = v2*t>=0 and t or nil
                    t = (nom-b)/a
                    t2 = v2*t>=0 and t or nil
                end
            end
        end
    elseif dist==0 then
        t1 = 0
    end
    return t1, GetCollisionPoint(t1), t2, GetCollisionPoint(t2), dist
end

function __gsoTPred:GetCurrentWayPoints(object)
    local result = {}
    local objectPos = object.pos
    if object.pathing.hasMovePath then
        local objectPath = object.pathing
        table.insert(result, Vector(objectPos.x,objectPos.y, objectPos.z))
        for i = objectPath.pathIndex, objectPath.pathCount do
            path = object:GetPath(i)
            table.insert(result, Vector(path.x, path.y, path.z))
        end
    else
        table.insert(result, object and Vector(objectPos.x,objectPos.y, objectPos.z) or Vector(objectPos.x,objectPos.y, objectPos.z))
    end
    return result
end

function __gsoTPred:GetDistanceSqr(p1, p2)
    if not p1 or not p2 then return 999999999 end
    return (p1.x - p2.x) ^ 2 + ((p1.z or p1.y) - (p2.z or p2.y)) ^ 2
end

function __gsoTPred:GetDistance(p1, p2)
    return mathSqrt(self:GetDistanceSqr(p1, p2))
end

function __gsoTPred:GetWaypointsLength(Waypoints)
    local result = 0
    for i = 1, #Waypoints -1 do
        result = result + self:GetDistance(Waypoints[i], Waypoints[i + 1])
    end
    return result
end

function __gsoTPred:CanMove(unit, delay)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if buff and buff.count > 0 and buff.duration>=delay then
            if (buff.type == 5 or buff.type == 8 or buff.type == 21 or buff.type == 22 or buff.type == 24 or buff.type == 11) then
                return false -- block everything
            end
        end
    end
    return true
end

function __gsoTPred:IsImmobile(unit, delay, radius, speed, from, spelltype)
    local unitPos = unit.pos
    local ExtraDelay = speed == math.huge and 0 or from and unit and unitPos and (self:GetDistance(from, unitPos) / speed)
    if (self:CanMove(unit, delay + ExtraDelay) == false) then
        return true
    end
    return false
end

function __gsoTPred:CalculateTargetPosition(unit, delay, radius, speed, from, spelltype)
    local Waypoints = {}
    local unitPos = unit.pos
    local Position, CastPosition = Vector(unitPos), Vector(unitPos)
    local t
    Waypoints = self:GetCurrentWayPoints(unit)
    local Waypointslength = self:GetWaypointsLength(Waypoints)
    local movementspeed = unit.pathing.isDashing and unit.pathing.dashSpeed or unit.ms
    if #Waypoints == 1 then
        Position, CastPosition = Vector(Waypoints[1].x, Waypoints[1].y, Waypoints[1].z), Vector(Waypoints[1].x, Waypoints[1].y, Waypoints[1].z)
        return Position, CastPosition
    elseif (Waypointslength - delay * movementspeed + radius) >= 0 then
        local tA = 0
        Waypoints = self:CutWaypoints(Waypoints, delay * movementspeed - radius)
        if speed ~= math.huge then
            for i = 1, #Waypoints - 1 do
                local A, B = Waypoints[i], Waypoints[i+1]
                if i == #Waypoints - 1 then
                    B = Vector(B) + radius * Vector(B - A):Normalized()
                end

                local t1, p1, t2, p2, D = self:VectorMovementCollision(A, B, movementspeed, Vector(from.x,from.y,from.z), speed)
                local tB = tA + D / movementspeed
                t1, t2 = (t1 and tA <= t1 and t1 <= (tB - tA)) and t1 or nil, (t2 and tA <= t2 and t2 <= (tB - tA)) and t2 or nil
                t = t1 and t2 and math.min(t1, t2) or t1 or t2
                if t then
                    CastPosition = t==t1 and Vector(p1.x, 0, p1.y) or Vector(p2.x, 0, p2.y)
                    break
                end
                tA = tB
            end
        else
            t = 0
            CastPosition = Vector(Waypoints[1].x, Waypoints[1].y, Waypoints[1].z)
        end
        if t then
            if (self:GetWaypointsLength(Waypoints) - t * movementspeed - radius) >= 0 then
                Waypoints = self:CutWaypoints(Waypoints, radius + t * movementspeed)
                Position = Vector(Waypoints[1].x, Waypoints[1].y, Waypoints[1].z)
            else
                Position = CastPosition
            end
        elseif unit.type ~= myHero.type then
            CastPosition = Vector(Waypoints[#Waypoints].x, Waypoints[#Waypoints].y, Waypoints[#Waypoints].z)
            Position = CastPosition
        end
    elseif unit.type ~= myHero.type then
        CastPosition = Vector(Waypoints[#Waypoints].x, Waypoints[#Waypoints].y, Waypoints[#Waypoints].z)
        Position = CastPosition
    end
    return Position, CastPosition
end

function __gsoTPred:VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), y = ay + rS * (by - ay) }
    return pointSegment, pointLine, isOnSegment
end

function __gsoTPred:CheckCol(unit, minion, Position, delay, radius, range, speed, from, draw)
    if unit.networkID == minion.networkID then 
        return false
    end
    local waypoints = self:GetCurrentWayPoints(minion)
    local minionPos = minion.pos
    local MPos, CastPosition = #waypoints == 1 and Vector(minionPos) or self:CalculateTargetPosition(minion, delay, radius, speed, from, "line")
    if from and MPos and self:GetDistanceSqr(from, MPos) <= (range)^2 and self:GetDistanceSqr(from, minionPos) <= (range + 100)^2 then
        local buffer = (#waypoints > 1) and 8 or 0 
        if minion.type == myHero.type then
            buffer = buffer + minion.boundingRadius
        end
        if #waypoints > 1 then
            local proj1, pointLine, isOnSegment = self:VectorPointProjectionOnLineSegment(from, Position, Vector(MPos))
            if proj1 and isOnSegment and (self:GetDistanceSqr(MPos, proj1) <= (minion.boundingRadius + radius + buffer) ^ 2) then
                return true
            end
        end
        local proj2, pointLine, isOnSegment = self:VectorPointProjectionOnLineSegment(from, Position, Vector(minionPos))
        if proj2 and isOnSegment and (self:GetDistanceSqr(minionPos, proj2) <= (minion.boundingRadius + radius + buffer) ^ 2) then
            return true
        end
    end
end

function __gsoTPred:CheckMinionCollision(unit, Position, delay, radius, range, speed, from)
    Position = Vector(Position)
    from = from and Vector(from) or myHero.pos
    for i = 1, #gsoAIO.OB.enemyMinions do
        local minion = gsoAIO.OB.enemyMinions[i]
        if minion and not minion.dead and minion.isTargetable and minion.visible and minion.valid and self:CheckCol(unit, minion, Position, delay, radius, range, speed, from, draw) then
            return true
        end
    end
    return false
end

function __gsoTPred:isSlowed(unit, delay, speed, from)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if buff and from and buff.count > 0 and buff.duration>=(delay + self:GetDistance(unit.pos, from) / speed) then
            if (buff.type == 10) then
                return true
            end
        end
    end
    return false
end

function __gsoTPred:GetBestCastPosition(unit, delay, radius, range, speed, from, collision, spelltype)
    range = range and range - 4 or math.huge
    radius = radius == 0 and 1 or radius - 4
    speed = speed and speed or math.huge
    local mePos = myHero.pos
    local hePos = unit.pos
    if not from then
        from = Vector(mePos)
    end
    local IsFromMyHero = self:GetDistanceSqr(from, mePos) < 50*50 and true or false
    delay = delay + (0.07 + Game.Latency() / 2000)
    local Position, CastPosition = self:CalculateTargetPosition(unit, delay, radius, speed, from, spelltype)
    local HitChance = 1
    if (self:IsImmobile(unit, delay, radius, speed, from, spelltype)) then
        HitChance = 5
    end
    Waypoints = self:GetCurrentWayPoints(unit)
    if (#Waypoints == 1) then
        HitChance = 2
    end
    if self:isSlowed(unit, delay, speed, from) then
        HitChance = 2
    end
    if (unit.activeSpell and unit.activeSpell.valid) then
        HitChance = 2
    end
    if self:GetDistance(mePos, hePos) < 250 then
        HitChance = 2
        Position, CastPosition = self:CalculateTargetPosition(unit, delay*0.5, radius, speed*2, from, spelltype)
        Position = CastPosition
    end
    local angletemp = Vector(from):AngleBetween(Vector(hePos), Vector(CastPosition))
    if angletemp > 60 then
        HitChance = 1
    elseif angletemp < 30 then
        HitChance = 2
    end
    --[[Out of range]]
    if IsFromMyHero then
        if (spelltype == "line" and self:GetDistanceSqr(from, Position) >= range * range) then
            HitChance = 0
        end
        if (spelltype == "circular" and (self:GetDistanceSqr(from, Position) >= (range + radius)*(range + radius))) then
            HitChance = 0
        end
        if from and Position and (self:GetDistanceSqr(from, Position) > range * range) then
            HitChance = 0
        end
    end
    radius = radius*2
    if collision and HitChance > 0 then
        if collision and self:CheckMinionCollision(unit, hePos, delay, radius, range, speed, from) then
            HitChance = -1
        elseif self:CheckMinionCollision(unit, Position, delay, radius, range, speed, from) then
            HitChance = -1
        elseif self:CheckMinionCollision(unit, CastPosition, delay, radius, range, speed, from) then
            HitChance = -1
        end
    end
    if not CastPosition or not Position then
        HitChance = -1
    end
    return CastPosition, HitChance, Position
end