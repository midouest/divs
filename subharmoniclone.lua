-- subharmoniclone
MusicUtil = require('musicutil')

pitch_offset_v = -5

function init()
    crow.ii.jf.mode(1)

    voices = {
        {offset = 0, level = 5},
        {subdivision = 1, level = 0},
        {subdivision = 1, level = 0},
        {offset = 0, level = 5},
        {subdivision = 1, level = 0},
        {subdivision = 1, level = 0},
    }

    sequencers = {
        {
            index = 1,
            steps = {0, 0, 0, 0},
            offset = 0,
            targets = {true, false, false}
        },
        {
            index = 1,
            steps = {0, 0, 0, 0},
            offset = 3,
            targets = {true, false, false}
        },
    }

    rhythm_generators = {
        {subdivision = 1, targets = {true, false}},
        {subdivision = 1, targets = {false, true}},
        {subdivision = 1, targets = {false, false}},
        {subdivision = 1, targets = {false, false}},
    }

    for i = 1, #rhythm_generators do
        run_rhythm_generator(i)
    end
end

function cleanup()
    crow.ii.jf.mode(0)
end

function get_main_index(index)
    return (index - 1) // 3 * 3 + 1
end

function n2v(n)
    return n / 12 + pitch_offset_v
end

function f2v(f)
    return math.log(f / MusicUtil.note_num_to_freq(60), 2)
end

function trigger_voice(index, offset)
    local main_index = get_main_index(index)
    local main_voice = voices[main_index]
    local main_note = 60 + offset + main_voice.offset
    local is_main = index == main_index
    local voice = voices[index]

    local pitch
    if is_main then
        pitch = n2v(main_note)
    else
        local main_freq = MusicUtil.note_num_to_freq(main_note)
        local subdivision = util.clamp(voice.subdivision + offset, 1, 16)
        local sub_freq = main_freq / subdivision
        pitch = f2v(sub_freq)
    end

    crow.ii.jf.play_voice(index, pitch, voice.level)
end

function run_rhythm_generator(index)
    return clock.run(rhythm_generator_loop, index)
end

function rhythm_generator_loop(index)
    while true do
        local rhythm_generator = rhythm_generators[index]
        update_rhythm_generator(rhythm_generator)
        clock.sync(1 / rhythm_generator.subdivision)
    end
end

function update_rhythm_generator(rhythm_generator)
    for target_index = 1, #rhythm_generator.targets do
        if rhythm_generator.targets[target_index] then
            trigger_sequencer(target_index)
        end
    end
end

function trigger_sequencer(index)
    local sequencer = sequencers[index]
    local step_offset = sequencer.steps[sequencer.index]
    for target_index = 1, #sequencer.targets do
        local offset = 0
        if sequencer.targets[target_index] then
            offset = step_offset
        end
        trigger_voice(target_index + sequencer.offset, step_offset)
    end
    sequencer.index = sequencer.index % #sequencer.steps + 1
end
