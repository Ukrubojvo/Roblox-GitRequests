local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local lookupValueToCharacter = buffer.create(64)
local lookupCharacterToValue = buffer.create(256)

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local padding = string.byte("=")

for index = 1, 64 do
	local value = index - 1
	local character = string.byte(alphabet, index)
	
	buffer.writeu8(lookupValueToCharacter, value, character)
	buffer.writeu8(lookupCharacterToValue, character, value)
end

local function encode(input: buffer): buffer
	local inputLength = buffer.len(input)
	local inputChunks = math.ceil(inputLength / 3)
	
	local outputLength = inputChunks * 4
	local output = buffer.create(outputLength)
	
	for chunkIndex = 1, inputChunks - 1 do
		local inputIndex = (chunkIndex - 1) * 3
		local outputIndex = (chunkIndex - 1) * 4
		
		local chunk = bit32.byteswap(buffer.readu32(input, inputIndex))
		
		local value1 = bit32.rshift(chunk, 26)
		local value2 = bit32.band(bit32.rshift(chunk, 20), 0b111111)
		local value3 = bit32.band(bit32.rshift(chunk, 14), 0b111111)
		local value4 = bit32.band(bit32.rshift(chunk, 8), 0b111111)
		
		buffer.writeu8(output, outputIndex, buffer.readu8(lookupValueToCharacter, value1))
		buffer.writeu8(output, outputIndex + 1, buffer.readu8(lookupValueToCharacter, value2))
		buffer.writeu8(output, outputIndex + 2, buffer.readu8(lookupValueToCharacter, value3))
		buffer.writeu8(output, outputIndex + 3, buffer.readu8(lookupValueToCharacter, value4))
	end
	
	local inputRemainder = inputLength % 3
	
	if inputRemainder == 1 then
		local chunk = buffer.readu8(input, inputLength - 1)
		
		local value1 = bit32.rshift(chunk, 2)
		local value2 = bit32.band(bit32.lshift(chunk, 4), 0b111111)

		buffer.writeu8(output, outputLength - 4, buffer.readu8(lookupValueToCharacter, value1))
		buffer.writeu8(output, outputLength - 3, buffer.readu8(lookupValueToCharacter, value2))
		buffer.writeu8(output, outputLength - 2, padding)
		buffer.writeu8(output, outputLength - 1, padding)
	elseif inputRemainder == 2 then
		local chunk = bit32.bor(
			bit32.lshift(buffer.readu8(input, inputLength - 2), 8),
			buffer.readu8(input, inputLength - 1)
		)

		local value1 = bit32.rshift(chunk, 10)
		local value2 = bit32.band(bit32.rshift(chunk, 4), 0b111111)
		local value3 = bit32.band(bit32.lshift(chunk, 2), 0b111111)
		
		buffer.writeu8(output, outputLength - 4, buffer.readu8(lookupValueToCharacter, value1))
		buffer.writeu8(output, outputLength - 3, buffer.readu8(lookupValueToCharacter, value2))
		buffer.writeu8(output, outputLength - 2, buffer.readu8(lookupValueToCharacter, value3))
		buffer.writeu8(output, outputLength - 1, padding)
	elseif inputRemainder == 0 and inputLength ~= 0 then
		local chunk = bit32.bor(
			bit32.lshift(buffer.readu8(input, inputLength - 3), 16),
			bit32.lshift(buffer.readu8(input, inputLength - 2), 8),
			buffer.readu8(input, inputLength - 1)
		)

		local value1 = bit32.rshift(chunk, 18)
		local value2 = bit32.band(bit32.rshift(chunk, 12), 0b111111)
		local value3 = bit32.band(bit32.rshift(chunk, 6), 0b111111)
		local value4 = bit32.band(chunk, 0b111111)

		buffer.writeu8(output, outputLength - 4, buffer.readu8(lookupValueToCharacter, value1))
		buffer.writeu8(output, outputLength - 3, buffer.readu8(lookupValueToCharacter, value2))
		buffer.writeu8(output, outputLength - 2, buffer.readu8(lookupValueToCharacter, value3))
		buffer.writeu8(output, outputLength - 1, buffer.readu8(lookupValueToCharacter, value4))
	end
	
	return output
end

local function decode(input: buffer): buffer
	local inputLength = buffer.len(input)
	local inputChunks = math.ceil(inputLength / 4)

	local inputPadding = 0
	if inputLength ~= 0 then
		if buffer.readu8(input, inputLength - 1) == padding then inputPadding += 1 end
		if buffer.readu8(input, inputLength - 2) == padding then inputPadding += 1 end
	end

	local outputLength = inputChunks * 3 - inputPadding
	local output = buffer.create(outputLength)
	
	for chunkIndex = 1, inputChunks - 1 do
		local inputIndex = (chunkIndex - 1) * 4
		local outputIndex = (chunkIndex - 1) * 3
		
		local value1 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, inputIndex))
		local value2 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, inputIndex + 1))
		local value3 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, inputIndex + 2))
		local value4 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, inputIndex + 3))
		
		local chunk = bit32.bor(
			bit32.lshift(value1, 18),
			bit32.lshift(value2, 12),
			bit32.lshift(value3, 6),
			value4
		)
		
		local character1 = bit32.rshift(chunk, 16)
		local character2 = bit32.band(bit32.rshift(chunk, 8), 0b11111111)
		local character3 = bit32.band(chunk, 0b11111111)
		
		buffer.writeu8(output, outputIndex, character1)
		buffer.writeu8(output, outputIndex + 1, character2)
		buffer.writeu8(output, outputIndex + 2, character3)
	end
	
	if inputLength ~= 0 then
		local lastInputIndex = (inputChunks - 1) * 4
		local lastOutputIndex = (inputChunks - 1) * 3
		
		local lastValue1 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, lastInputIndex))
		local lastValue2 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, lastInputIndex + 1))
		local lastValue3 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, lastInputIndex + 2))
		local lastValue4 = buffer.readu8(lookupCharacterToValue, buffer.readu8(input, lastInputIndex + 3))

		local lastChunk = bit32.bor(
			bit32.lshift(lastValue1, 18),
			bit32.lshift(lastValue2, 12),
			bit32.lshift(lastValue3, 6),
			lastValue4
		)
		
		if inputPadding <= 2 then
			local lastCharacter1 = bit32.rshift(lastChunk, 16)
			buffer.writeu8(output, lastOutputIndex, lastCharacter1)
			
			if inputPadding <= 1 then
				local lastCharacter2 = bit32.band(bit32.rshift(lastChunk, 8), 0b11111111)
				buffer.writeu8(output, lastOutputIndex + 1, lastCharacter2)
				
				if inputPadding == 0 then
					local lastCharacter3 = bit32.band(lastChunk, 0b11111111)
					buffer.writeu8(output, lastOutputIndex + 2, lastCharacter3)
				end
			end
		end
	end
	
	return output
end

local base64 = {
	encode = encode,
	decode = decode,
}

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
    local url = self.API_BASE_URL .. self.username .. "/" .. self.repository .. "/contents/" .. filePath .. (ref and ("?ref=" .. ref) or "")
    
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
            return buffer.tostring(base64.decode(buffer.fromstring(data.content:gsub("\n", ""))))
        else
            error("파일 내용을 가져올 수 없습니다.")
        end
    else
        error("GitHub API 요청 실패: " .. response.StatusCode)
    end
end

return GitRequests
