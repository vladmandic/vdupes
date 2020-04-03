#!/usr/bin/env julia
using Base
using Logging
using Dates
using SHA

# includeList = [ "C:\\Users\\mandi\\OneDrive\\Temp", "C:\\Users\\mandi\\OneDrive\\Scans" ]
includeList = [ "/home/root", "/home/vlado", ]
excludeList = [ Regex("/Camera Roll"), Regex(".lrcat"), Regex(".lrdata"), Regex("/Prints"), Regex("System Volume Information") ]

filesExcluded = 0
filesIncluded = 0
filesSkipped = 0
filesDuplicate = 0
filesError = 0
foldersWalked = 0
files = Dict{}() # structure will be hash of the content plus a tuple of filename/size/ctime/mtime
buf = Vector{UInt8}(undef, 1024*1024)

function dt(t)
    return Dates.format(unix2datetime(t), "mm/dd/YYYY-HH:MM:SS")
end

function checkFile(fileName)
    try
        if filesIncluded % 1000 == 0
#            print(".") # print . for progress every 1000 files
        end
        st = lstat(fileName)
        global filesIncluded += 1
        if (st.size > 64*1024) # only check files larger than 64k
            @debug "checkFile: $fileName"
            fd = open(fileName, "r")
            bytes = readbytes!(fd, buf, 1024*1024, all=false) # read first 1MB of the file to calculate sha2 hash
            close(fd)
            hash = bytes2hex(sha256(buf))
            if haskey(files, hash)
                global filesDuplicate += 1
                @info "duplicate: $fileName size=$(st.size) ctime=$(dt(st.ctime)) mtime=$(dt(st.mtime))"
                @info "original:  $(files[hash].name) size=$(files[hash].size) ctime=$(dt(files[hash].ctime)) mtime=$(dt(files[hash].mtime))"
            end
            global files[hash] = (name = fileName, size = st.size, ctime = st.ctime, mtime = st.mtime)
        else
            global filesSkipped += 1
        end
        return true
    catch err
        global filesError += 1
        @error "$fileName: $err"
        return false
    end
end

function excludeFile(file)
    for regex in excludeList
        if match(regex, file) !== nothing
            global filesExcluded += 1
            return true
        end
    end
    return false
end

function walkDir(dir)
    try
        global foldersWalked += 1
        dirFiles = readdir(dir)
        for fileName in dirFiles
            f = joinpath(dir, fileName)
            if excludeFile(f)
                continue
            end
            if isdir(f)
                walkDir(f)
            elseif isfile(f)
                checkFile(f)
            end
        end
    catch err
        global filesError += 1
        @error "$dir: $err"
    end
end

function startDirScan()
    for dir in includeList
        @info "processing dir: $dir"
        try
            walkDir(dir)
        catch err
            @error "$dir $err"
        end
        @info "finished dir: $dir"
    end
    @info "folders walked: $foldersWalked"
    @info "objects included: $filesIncluded"
    @info "objects excluded: $filesExcluded"
    @info "objects skipped: $filesSkipped"
    @info "objects with duplicates: $filesDuplicate"    
    @info "objects with error: $filesError"
end

function init()
#    global logFile = open("vDupes.log", "w+")
#    logger = SimpleLogger(logFile, Logging.Info, Dict{Any,Int64}())
    logger = ConsoleLogger(stdout, Logging.Info; meta_formatter=Logging.default_metafmt, show_limited=true, right_justify=0)
    global_logger(logger)
end

function finish()
#    flush(logFile)
#    close(logFile)
end

function main()
    @info "vdupes starting"
    init()
    time = @elapsed startDirScan()
    speed = round(filesIncluded / time, RoundUp)
    @info "vdupes finished in: $time sec ($speed files/sec)"
    finish()
end

main()
