bit32 = require("bit32")

--[ This section opens the file if it's specified, and checks if it's valid ]--
if arg[1] == nil or arg[1] == "--help" or arg[1] == "-h" then
	print("Usage: "..arg[0].." <PATH TO WAVE FILE>/<--help>/<-h>")
	print("<PATH TO WAVE FILE>: The path to a WAVE file, duh.")
	return 1
end

speaker = peripheral.find("speaker")
if not speaker then
    print("Error: No speaker detected")
    return 1
end

f = assert(io.open(arg[1], "rb"))
wave = f:read("*all")
assert(f:close())

-- Function to read little endian data
function read_le(binary, offset, count)
    data = 0
    i=count-1
    while i >= 0 do
    	data = bit32.bor(data, bit32.lshift(string.byte(binary, offset+i+1, offset+i+1), 8*i))
    	i=i-1
    end
    return data
end

-- Check file ID (must be RIFF)
if string.sub(wave, 1, 4) ~= "RIFF" then
	print("Error: The specified file is not a RIFF file")
	return 1
end

--[ This section gets information from the master RIFF chunk of the file header ]--

-- Check if the filesize is correct
if string.len(wave) ~= read_le(wave, 4, 4)+8 then
	print("Error: Filesize is not correct! The file may be corrupt.")
	return 1
end

-- Check file format (must be WAVE)
if string.sub(wave, 9, 12) ~= "WAVE" then
    print("Error: The specified file is not a WAVE file")
    return 1
end

--[ This section gets information from the data format chunk ]--
-- Check "FormatBlocID" (at least that's what Wikipedia calls it)
if string.sub(wave, 13, 16) ~= "fmt " then
    print("Error: Format block ID thingy != \"fmt \"")
    return 1
end

-- Get the chunk size
chunk_size = read_le(wave, 16, 4)

-- Check audio format (this player only supports PCM)
if read_le(wave, 20, 2) ~= 1 then
    print("Error: This WAVE player only supports PCM audio")
    return 1
end

-- Get some more info about the audio file
channels = read_le(wave, 22, 2)
sample_rate = read_le(wave, 24, 4)
data_rate = read_le(wave, 28, 4)
block_size = read_le(wave, 32, 2)
bytes_per_sample = math.floor(block_size / channels)

-- i can't be bothered to figure out resampling so take this instead
if sample_rate ~= 48000 then
    print("Warning: This audio file's sample rate is not 48 KHz.")
    print("The audio might be sped up or slowed down.")
end

-- Search for data chunk
-- i don't think this is the best way but it works :shrug:
pointer = 36
while string.sub(wave, pointer-3, pointer) ~= "data" do
    pointer = pointer + 1
end

-- Get the size of the data chunk
data_chunk_size = read_le(wave, pointer, 4)

while pointer < data_chunk_size do
    buffer = {}
    for i=1,16 * 1024 * 8 do
        sample = read_le(wave, pointer, bytes_per_sample)
        if bytes_per_sample == 2 then
            sample = sample / 256
        end
        pointer = pointer + bytes_per_sample*2
        if sample > 127 then
            sample = sample - 256
        end
        buffer[i] = sample
    end
    
    while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
    end
end

