--[[

##                              ####   #####
##       #  #                  ##  ##  ##  ##
##                                 ##  ##  ##
##       ####   ##  ##   ####    ###   ##  ##
##      ##  ##  ##  ##  ##  ##     ##  ##  ##
##      ##  ##  ##  ##  #####      ##  ##  ##
##  ##  ##  ##   ####   ##     ##  ##  ##  ##
######   ####     ##     ####   ####   #####

Love3D v1.0

Copyright © 2026 i rember
Licensed under the same license as LÖVE

]]

local p = {}

p.vec = {
    new = function(x, y, z)
        return setmetatable({x = x, y = y, z = z}, {__index = p.vec})
    end,

    add = function(a, b)
        return p.vec.new(a.x + b.x, a.y + b.y, a.z + b.z)
    end,

    neg = function(v)
        return p.vec.new(-v.x, -v.y, -v.z)
    end,

    sub = function(a, b)
        return p.vec.new(a.x - b.x, a.y - b.y, a.z - b.z)
    end,

    scale = function(v, scalar)
        return p.vec.new(v.x * scalar, v.y * scalar, v.z * scalar)
    end,

    dot = function(a, b)
        return a.x * b.x + a.y * b.y + a.z * b.z
    end,

    cross = function(a, b)
        return p.vec.new(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x
        )
    end,

    length = function(v)
        return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    end,

    normalize = function(v)
        local length = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if length == 0 then
            return p.vec.new(0,0,0)
        end
        return p.vec.new(v.x / length, v.y / length, v.z / length)
    end,

    -- rotation functions take rotation in radians
    rotx = function(v, rotation, center)
        center = center or p.vec.new(0, 0, 0)
        v = v:sub(center)

        local cosine = math.cos(rotation)
        local sine = math.sin(rotation)
        local y = v.y * cosine - v.z * sine
        local z = v.y * sine + v.z * cosine

        return p.vec.new(v.x, y, z):add(center)
    end,

    roty = function(v, rotation, center)
        center = center or p.vec.new(0, 0, 0)
        v = v:sub(center)

        local cosine = math.cos(rotation)
        local sine = math.sin(rotation)
        local x = v.x * cosine + v.z * sine
        local z = -v.x * sine + v.z * cosine

        return p.vec.new(x, v.y, z):add(center)
    end,

    rotz = function(v, rotation, center)
        center = center or p.vec.new(0, 0, 0)
        v = v:sub(center)

        local cosine = math.cos(rotation)
        local sine = math.sin(rotation)
        local x = v.x * cosine - v.y * sine
        local y = v.x * sine + v.y * cosine

        return p.vec.new(x, y, v.z):add(center)
    end,

    -- rotation order: z, x, y
    rotate = function(v, rotation, center)
        v = v:rotz(rotation.z, center)
        v = v:rotx(rotation.x, center)
        v = v:roty(rotation.y, center)
        return v
    end,

    invrotate = function(v, rotation, center)
        v = v:roty(-rotation.y, center)
        v = v:rotx(-rotation.x, center)
        v = v:rotz(-rotation.z, center)
        return v
    end,

    id = "vec"
}

p.near_distance = 0.1
p.far_distance = 25

p.camera = {
    pos = p.vec.new(0, 0, 0),
    rot = p.vec.new(0, 0, 0),
    fov = 90 -- vertical field of view; degrees
}

local function project(v)
    local relative = v:sub(p.camera.pos)
    local camera_space = relative:invrotate(p.camera.rot)

    if camera_space.z <= 0 then
        return nil
    end

    return {
        x = camera_space.x / camera_space.z,
        y = camera_space.y / camera_space.z,
        z = camera_space.z
    }
end

local function project_camera_space(v)
    return {
        x = v.x / v.z,
        y = v.y / v.z,
        z = v.z
    }
end

p.scene = {}

local function add(i)
    p.scene[#p.scene+1] = i
    return i
end

local function copy(i)
    local result = {}
    for key, value in pairs(i) do
        result[key] = value
    end
    return setmetatable(result, getmetatable(i))
end

p.triangle = {
    new = function(p1, p2, p3, color)
        return setmetatable(
            {
                p1 = p1,
                p2 = p2,
                p3 = p3,
                color = color
            }, {__index = p.triangle}
        )
    end,

    add = add,
    copy = copy,

    clip = function(tri, a, b, c, d)
        local vertices = {tri.p1, tri.p2, tri.p3}
        local clipped = {}

        local function signed_distance(v)
            return a * v.x + b * v.y + c * v.z - d
        end

        for i = 1, 3 do
            local current = vertices[i]
            local previous = vertices[i == 1 and 3 or i - 1]
            local current_distance = signed_distance(current)
            local previous_distance = signed_distance(previous)
            local current_inside = current_distance >= 0
            local previous_inside = previous_distance >= 0

            if current_inside ~= previous_inside then
                local t = previous_distance / (previous_distance - current_distance)
                clipped[#clipped + 1] = p.vec.new(
                    previous.x + (current.x - previous.x) * t,
                    previous.y + (current.y - previous.y) * t,
                    previous.z + (current.z - previous.z) * t
                )
            end

            if current_inside then
                clipped[#clipped + 1] = current
            end
        end

        if #clipped < 3 then
            return {}
        end

        local triangles = {
            p.triangle.new(clipped[1], clipped[2], clipped[3], tri.color)
        }
        if #clipped == 4 then
            triangles[#triangles + 1] = p.triangle.new(
                clipped[1], clipped[3], clipped[4], tri.color
            )
        end
        return triangles
    end,
    
    normal = function(tri)
        return p.vec.normalize(p.vec.cross(
            p.vec.sub(tri.p2, tri.p1),
            p.vec.sub(tri.p3, tri.p1)
        ))
    end,

    id = "triangle"
}

p.meshes = {}
function p.load_mesh(name, filename)
    if p.meshes[name] then
        error("Mesh with name \"" .. name .. "\" already exists")
    end

    local data, err = love.filesystem.read(filename)
    if not data then
        error(err or ("Unable to read OBJ file: " .. filename))
    end

    local points = {}
    local triangles = {}

    local function resolve_index(value)
        local index = tonumber(value)
        if not index then
            return nil
        end
        if index < 0 then
            return #points + index + 1
        end
        return index
    end

    for line in data:gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        local kind, values = line:match("^(%S+)%s*(.*)$")

        if kind == "v" then
            local x, y, z = values:match("^(%S+)%s+(%S+)%s+(%S+)")
            if x and y and z then
                points[#points + 1] = p.vec.new(
                    tonumber(x), tonumber(y), tonumber(z)
                )
            end
        elseif kind == "f" then
            local face = {}
            for vertex in values:gmatch("%S+") do
                local position = vertex:match("^([^/]+)")
                local index = resolve_index(position)
                if index then
                    face[#face + 1] = index
                end
            end

            for i = 2, #face - 1 do
                local p1 = points[face[1]]
                local p2 = points[face[i]]
                local p3 = points[face[i + 1]]
                if p1 and p2 and p3 then
                    triangles[#triangles + 1] = p.triangle.new(
                        p1, p2, p3, {1, 1, 1}
                    )
                end
            end
        end
    end

    p.meshes[name] = triangles
    return triangles
end

p.model = {
    new = function(mesh, pos, color, rot, scale)
        if not rot then rot = p.vec.new(0, 0, 0) end
        if not scale then scale = p.vec.new(1, 1, 1) end
        return setmetatable(
            {
                mesh = mesh,
                pos = pos,
                color = color,
                rot = rot,
                scale = scale
            }, {__index = p.model}
        )
    end,

    add = add,
    copy = copy,

    id = "model"
}

p.lighting_normal = p.vec.new(0.1, 1.0, 0.5):normalize()

local unpk = table.unpack or unpack

function p.render()
    -- just in case
    p.lighting_normal = p.lighting_normal:normalize()

    local triangles = {}

    for _, a in ipairs(p.scene) do
        if a.id and a.id == "triangle" then
            triangles[#triangles+1] = a
        elseif a.id and a.id == "model" then
            local mesh = p.meshes[a.mesh]
            if not mesh then
                error("Unknown mesh: " .. tostring(a.mesh))
            end

            for _, triangle in ipairs(mesh) do
                local function transform(vertex)
                    local transformed = p.vec.new(
                        vertex.x * a.scale.x,
                        vertex.y * a.scale.y,
                        vertex.z * a.scale.z
                    )
                    transformed = transformed:rotate(a.rot:scale(math.pi / 180))
                    return transformed:add(a.pos)
                end

                triangles[#triangles + 1] = p.triangle.new(
                    transform(triangle.p1),
                    transform(triangle.p2),
                    transform(triangle.p3),
                    a.color
                )
            end
        else
            error("Unknown object in love3d.scene")
        end
    end

    local shaded = {}
    for _, t in ipairs(triangles) do
        local diffuse = t:normal():dot(p.lighting_normal)
        local brightness = 0.5 + 0.25 * diffuse

        local tri = t:copy()
        local color = tri.color or {1, 1, 1}
        tri.color = {
            (color[1] or 1) * brightness,
            (color[2] or 1) * brightness,
            (color[3] or 1) * brightness
        }
        shaded[#shaded+1] = tri
    end
    
    local aspect = love.graphics.getWidth() / love.graphics.getHeight()
    local scale = math.tan(math.rad(p.camera.fov) / 2)

    local planes = {
        {0, 0, 1, p.near_distance}, -- near
        {0, 0, -1, -p.far_distance}, -- far
        {1, 0, aspect * scale, 0}, -- left
        {-1, 0, aspect * scale, 0}, -- right
        {0, 1, scale, 0}, -- top
        {0, -1, scale, 0} -- bottom
    }

    local clipped = {}
    for _, t in ipairs(shaded) do

        local p1 = t.p1
        local p2 = t.p2
        local p3 = t.p3

        if p1 and p2 and p3 then
            local function to_camera_space(v)
                return v:sub(p.camera.pos):invrotate(p.camera.rot)
            end

            local base = {p.triangle.new(
                to_camera_space(p1),
                to_camera_space(p2),
                to_camera_space(p3),
                t.color
            )}

            for _, plane in ipairs(planes) do
                local nxt = {}
                for _, tri in ipairs(base) do
                    for _, result in ipairs(tri:clip(unpk(plane))) do
                        nxt[#nxt + 1] = result
                    end
                end
                base = nxt
            end

            for _, tri in ipairs(base) do
                clipped[#clipped + 1] = tri
            end
        end
    end

    local to_render = {}
    for _, t in ipairs(clipped) do
        local p1 = project_camera_space(t.p1)
        local p2 = project_camera_space(t.p2)
        local p3 = project_camera_space(t.p3)

        local width, height = love.graphics.getDimensions()
        local scale = math.tan(math.rad(p.camera.fov) / 2)
        local aspect = width / height

        p1.x = width / 2 + p1.x * width / (2 * scale * aspect)
        p1.y = height / 2 - p1.y * height / (2 * scale)
        p2.x = width / 2 + p2.x * width / (2 * scale * aspect)
        p2.y = height / 2 - p2.y * height / (2 * scale)
        p3.x = width / 2 + p3.x * width / (2 * scale * aspect)
        p3.y = height / 2 - p3.y * height / (2 * scale)

        if p1 and p2 and p3 then
            local signed_area =
                (p2.x - p1.x) * (p3.y - p1.y) -
                (p2.y - p1.y) * (p3.x - p1.x)

            if signed_area > 0 then
                to_render[#to_render+1] = p.triangle.new(p1, p2, p3, t.color)
            end
        end
    end

    table.sort(to_render, function(a, b)
        local depth_a = (a.p1.z + a.p2.z + a.p3.z) / 3
        local depth_b = (b.p1.z + b.p2.z + b.p3.z) / 3
        return depth_a > depth_b
    end)

    for _, tri in ipairs(to_render) do
        love.graphics.setColor(tri.color)
        love.graphics.polygon(
            "fill",
            tri.p1.x, tri.p1.y,
            tri.p2.x, tri.p2.y,
            tri.p3.x, tri.p3.y
        )
    end

    love.graphics.setColor(1,1,1)
end

return p