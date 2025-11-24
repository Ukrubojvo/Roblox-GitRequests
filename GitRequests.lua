local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local base64 = loadstring(game:HttpGet("https://raw.githubusercontent.com/itchino/Roblox-GitRequests/refs/heads/main/Base64.lua"))()

local GitRequests = {}
GitRequests.__index = GitRequests
GitRequests.API_BASE_URL = "https://api.github.com/repos/"

--[[
    GitRequests 클래스 생성자

    파라미터:
    username: GitHub 사용자 이름
    repository: 저장소 이름

    반환값: GitRequests 클래스 인스턴스

    사용 예시:
    local gitRequestsInstance = GitRequests.Repo("username", "repository")
]]
function GitRequests.Repo(username, repository)
    local self = setmetatable({}, GitRequests)
    self.username = username
    self.repository = repository
    return self
end

--[[
    파일 요청 함수

    파라미터:
    filePath: 저장소 내 파일 경로
    ref: 브렌치, 태그 또는 커밋 SHA (선택 사항)

    반환값: 파일 내용 (문자열) 또는 nil (오류 시)

    사용 예시:
    local content = gitRequestsInstance:getFileContent("main.lua")
    local contentAtBranch = gitRequestsInstance:getFileContent("main.lua", "develop")
    local contentAtCommit = gitRequestsInstance:getFileContent("main.lua", "a1b2c3d4")
    local contentAtTag = gitRequestsInstance:getFileContent("main.lua", "v1.0.0")
]]
function GitRequests:getFileContent(filePath: string, ref: string?) : string?
    local url = GitRequests.API_BASE_URL .. self.username .. "/" .. self.repository .. "/contents/" .. filePath .. (ref and ("?ref=" .. ref) or "")
    
    local response

    if request then
        response = request({
            Method = "GET",
            Url = url
        })
    elseif not RunService:IsServer() then
        local raw_response = game:HttpGet(url)
        local json = HttpService:JSONDecode(raw_response)
        response = {
            StatusCode = json.content and 200 or 404,
            Body = raw_response
        }
    elseif HttpService.HttpEnabled then
        local success, result = pcall(function()
            return HttpService:GetAsync(url)
        end)
        if success then
            response = {
                StatusCode = 200,
                Body = result
            }
        else
            response = {
                StatusCode = 404,
                Body = ""
            }
        end
    else
        error("HTTP 요청이 비활성화되어 있습니다.")
    end
    if response.StatusCode == 200 then
        local data = HttpService:JSONDecode(response.Body)
        if data.content then
            return base64.decode(data.content:gsub("\n", ""))
        else
            error("파일 내용을 가져올 수 없습니다.")
        end
    else
        error("GitHub API 요청 실패: " .. response.StatusCode)
    end
end

return GitRequests