local leaderboard = {}
local filename = "leaderboard.txt"

function leaderboard.load()
    local data = {}
    if love.filesystem.getInfo(filename) then
        for line in love.filesystem.lines(filename) do
            local score, rooms = line:match("(%d+),(%d+)")
            if score and rooms then
                table.insert(data, {score = tonumber(score), rooms = tonumber(rooms)})
            end
        end
    end
    table.sort(data, function(a, b) return b.score < a.score end)
    return data
end

function leaderboard.save(score, rooms)
    local data = leaderboard.load()
    table.insert(data, {score = score, rooms = rooms})
    table.sort(data, function(a, b) return b.score < a.score end)
    
    local file = love.filesystem.newFile(filename, "w")
    for i = 1, math.min(10, #data) do
        file:write(data[i].score .. "," .. data[i].rooms .. "\n")
    end
    file:close()
end

return leaderboard
