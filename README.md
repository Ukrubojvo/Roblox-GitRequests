# Roblox-GitRequests

Roblox GitRequests는 깃허브의 캐싱을 우회하여 최신 커밋의 파일내용을 쉽게 가져오기 위한 라이브러리입니다.

## 사용법
```lua
local GitRequests = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ukrubojvo/Roblox-GitRequests/refs/heads/main/GitRequests.lua"))()
local Repo = GitRequests.Repo("username", "repo_name")
print(Repo:getFileContent("filePath"))
```
