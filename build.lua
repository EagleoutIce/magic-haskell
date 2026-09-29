#!/usr/bin/env texlua

-- l3build check | tag | ctan | upload | clean
bundle = ""
module = "magic-haskell"
ctanpkg = module
local tmpdir = os.getenv("TMPDIR")
if tmpdir == nil or tmpdir == "" then tmpdir = os.getenv("TEMP") end
if tmpdir == nil or tmpdir == "" then tmpdir = "/tmp" end
builddir = tmpdir .. "/" .. module

-- the version is the last tag vX.Y, "l3build tag" increments Y
-- no shell syntax beyond redirection, so that it runs in cmd.exe as well
local nullerr = os.type == "windows" and " 2>nul" or " 2>/dev/null"
local function capture(cmd)
    local handle = io.popen(cmd .. nullerr)
    local out = handle:read("*a") or ""
    handle:close()
    return (out:gsub("%s+$", ""))
end
local lasttagged = capture("git rev-list --tags --max-count=1")
local oldtag = lasttagged == "" and "" or capture("git describe --tags " .. lasttagged)
if oldtag == "" then oldtag = "v1.0" end
newsubtag = string.sub(oldtag, 4)
newmajortag = string.sub(oldtag, 0, 3)
if (options["target"] == "tag") then
    newsubtag = newsubtag + 1
end
packageversion = newmajortag .. math.floor(newsubtag)

packagedate = os.date("!%Y-%m-%d")

function git(...)
    local args = {...}
    table.insert(args, 1, 'git')
    local cmd = table.concat(args, ' ')
    print('Executing:', cmd)
    os.execute(cmd)
end

-- stamp the version and date into the .sty and -doc.tex files
tagfiles = {"*.sty", "*-doc.tex"}
function update_tag(file, content, tagname, tagdate)
    tagdate = string.gsub(packagedate, "-", "/")
    if string.match(file, "%.sty$") then
        content = string.gsub(content, "\\ProvidesPackage{(.-)}%[%d%d%d%d%/%d%d%/%d%d version v%d%.%d+",
            "\\ProvidesPackage{%1}[" .. tagdate .. " version " .. packageversion)
        return content
    elseif string.match(file, "%-doc%.tex$") then
        content = string.gsub(content, "\\date{Version v%d%.%d+ \\textendash{} %d%d%d%d%/%d%d%/%d%d",
            "\\date{Version " .. packageversion .. " \\textendash{} " .. tagdate)
        return content
    end
    return content
end

-- commit the retagged files and tag the commit; the release is pushed by hand
function tag_hook(tagname)
    git("add", "*.sty")
    git("add", "*-doc.tex")
    git('commit -m "step version ' .. packageversion .. '"')
    git("tag", packageversion)
end

-- xlistings is a dependency, taken from the submodule
local function copy_xlistings(dir)
    cp("xlistings.sty", "xlistings", dir)
    cp("xlistings-*.cfg", "xlistings/langs", dir)
    return 0
end

typesetfiles = {"magic-haskell-doc.tex"}
indexstyle = ""  -- the plain style of makeindex, not the one for .dtx files
function docinit_hook() return copy_xlistings(typesetdir) end

testfiledir = "tests"
testsuppdir = testfiledir .. "/support"
checkengines = {"pdftex"}
stdengine = "pdftex"
checkruns = 2  -- the definitions of a document need the aux file
function checkinit_hook() return copy_xlistings(testdir) end

textfiles = {"README.md"}
ctanreadme = "README.md"

installfiles = {"magic-haskell.sty", "magic-haskell-ghc.sty", "magic-haskell-links.cfg"}
sourcefiles = installfiles
unpackfiles = {}

packtdszip = false
flatten = true

uploadconfig = uploadconfig or {}
uploadconfig = {
    author = uploadconfig.author,
    uploader = uploadconfig.uploader,
    email = uploadconfig.email,
    pkg = ctanpkg,
    version = packageversion .. " " .. packagedate,
    license = "lppl1.3c",
    summary = "Haskell listings for xlistings with ligatures and Hackage links",
    ctanPath = "/macros/latex/contrib/" .. ctanpkg,
    repository = "https://github.com/EagleoutIce/" .. module,
    home = "https://github.com/EagleoutIce/" .. module,
    note = [[Uploaded automatically by l3build...]],
    bugtracker = "https://github.com/EagleoutIce/" .. module .. "/issues",
    announcement_file = "announcement.txt"
}

cleanfiles = {module .. "-ctan.curlopt", module .. "-ctan.zip"}
