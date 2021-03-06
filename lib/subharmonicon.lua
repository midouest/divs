local MusicUtil = require('musicutil')
local TabUtil = require('tabutil')

tempo_scale = 4
trigger_mode = 'or'

-- Static voltage offset added to notes before sending to synthesizer
local pitch_offset_v = -5

-- Convert a midi note to v/oct (+/- 5V)
local function n2v(n)
    return n / 12 + pitch_offset_v
end

-- MIDI note that will be 0V
local base_note = 60

-- Convert a frequency to v/oct (+/- 5V)
local function f2v(f)
    return math.log(f / MusicUtil.note_num_to_freq(base_note), 2)
end

-- Create a new voice state
-- @param index      Synthesizer voice index
-- @param main_index Index of the main voice that this voice follows. If index
--                   equals main_index, then the voice is a leader.
local function make_voice(index, main_index, seq_index, target_index)
    local voice = { seq = seq_index, target = target_index}
    if index == main_index then
        -- offset is the pitch offset applied to the main voice before the
        -- sequencer step offset is applied
        voice.offset = 0
        voice.level = 2
        voice.main = index
    else
        -- subdivision is the amount that the main voice frequence is divided
        -- by after the main voice offset and sequencer step offset have been
        -- applied
        voice.subdivision = 1
        voice.level = 0
        voice.main = main_index
    end
    return voice
end

-- Create a new sequencer state
-- @param main_index Index of the main voice that this sequencer drives
local function make_sequencer(main_index)
    return {
        index = 1,
        steps = {0, 0, 0, 0},
        main = main_index,
        targets = {true, false, false}
    }
end

-- Create a new rhythm generator state
-- @param seq1 True if the rhythm generator should trigger sequencer 1
-- @param seq2 True if the rhythm generator should trigger sequencer 2
local function make_rhythm_generator(seq1, seq2)
    return { subdivision = 1, targets = {seq1, seq2} }
end

local Subharmonicon = {}
Subharmonicon.__index = Subharmonicon

-- Create a new Subharmonicon instance
-- @param options Object with the following properties:
--                - play_voice(index, pitch_v, level_v)
--                - trigger_env_gen()
function Subharmonicon.new(options)
    local sh = {}

    sh._play_voice = options.play_voice or function() end
    sh._trigger_env_gen = options.trigger_env_gen or function() end

    -- Maximum sequencer step range. This is used to scale the offset that the
    -- sequencer applies to sub voices.
    sh._step_range = 24

    -- Voice state
    sh._voices = {
        make_voice(1, 1, 1, 1),
        make_voice(2, 1, 1, 2),
        make_voice(3, 1, 1, 3),
        make_voice(4, 4, 2, 1),
        make_voice(5, 4, 2, 2),
        make_voice(6, 4, 2, 3),
    }

    -- Sequencer state
    sh._sequencers = {
        make_sequencer(1),
        make_sequencer(4),
    }

    -- Rhythm generator state
    sh._rhythm_generators = {
        make_rhythm_generator(true, false),
        make_rhythm_generator(false, true),
        make_rhythm_generator(false, false),
        make_rhythm_generator(false, false),
    }

    sh._clock_ids = {}

    return setmetatable(sh, Subharmonicon)
end

function Subharmonicon:get_step_range()
    return self._step_range
end

function Subharmonicon:get_voice(index)
    return self._voices[index]
end

function Subharmonicon:get_sequencer(index)
    return self._sequencers[index]
end

function Subharmonicon:get_rhythm_generator(index)
    return self._rhythm_generators[index]
end

function Subharmonicon:start()
    self:stop()
    local id = self:_run_rhythm_generators()
    self._clock_ids = {id}
end

function Subharmonicon:stop()
    for _, id in ipairs(self._clock_ids) do
        clock.cancel(id)
    end
    self._clock_ids = {}
end

local function get_divisors(sh)
    local divisors = {}
    for i, gen in ipairs(sh._rhythm_generators) do
        table.insert(divisors, gen.subdivision)
    end
    return divisors
end

function Subharmonicon:_run_rhythm_generators(sh)
    return clock.run(function(sh)
        local beat = 0
        while true do
            local to_fire = {false, false}

            for i, rhythm_generator in ipairs(sh._rhythm_generators) do
                local should_fire = beat % rhythm_generator.subdivision == 0
                if should_fire then
                    for j, is_target in ipairs(rhythm_generator.targets) do
                        if trigger_mode == 'xor' then
                            local will_fire = to_fire[j]
                            to_fire[j] = (will_fire and not is_target) or (not will_fire and is_target)
                        else
                            to_fire[j] = to_fire[j] or is_target
                        end
                    end
                end
            end

            local any_fired = false
            for i, should_fire in ipairs(to_fire) do
                if should_fire then
                    any_fired = true
                    sh:_trigger_sequencer(i)
                end
            end

            if any_fired then
                sh._trigger_env_gen()
            end

            beat = beat + 1
            clock.sync(1 / tempo_scale)
        end
    end, self)
end

-- Trigger the sequencer at the given index
-- @param index Index of the sequencer in the global sequencer state
function Subharmonicon:_trigger_sequencer(index)
    local sequencer = self._sequencers[index]
    local step_offset = sequencer.steps[sequencer.index]
    for target_index = 1, #sequencer.targets do
        local main_offset = 0
        if sequencer.targets[1] then
            main_offset = step_offset
        end

        local voice_offset = 0
        if sequencer.targets[target_index] then
            voice_offset = step_offset
        end

        local voice_index = target_index + (sequencer.main - 1)
        self:_trigger_voice(voice_index, main_offset, voice_offset)
    end
    sequencer.index = sequencer.index % #sequencer.steps + 1
end

-- Trigger a synthesizer voice
-- @param index       Voice index to be triggered
-- @param offset      Step offset in semitones applied to the voice by the sequencer
function Subharmonicon:_trigger_voice(index, main_offset, voice_offset)
    local voice = self._voices[index]
    local is_main = index == voice.main
    local main_voice = is_main and voice or self._voices[voice.main]
    local main_note = base_note + main_offset + main_voice.offset

    local pitch
    if is_main then
        pitch = n2v(main_note)
    else
        local main_freq = MusicUtil.note_num_to_freq(main_note)
        local sub_offset = util.round(util.linlin(-self._step_range, self._step_range, -16, 16, voice_offset), 1)
        local subdivision = util.clamp(voice.subdivision + sub_offset, 1, 16)
        local sub_freq = main_freq / subdivision
        pitch = f2v(sub_freq)
    end

    self._play_voice(index, pitch, voice.level)
end

return Subharmonicon
