-- divs
-- a Moog Subharmonicon clone
-- midouest@0.0.1

MusicUtil = require("musicutil")

Subharmonicon = include("lib/subharmonicon")
Page = include("lib/page")
Table = include("lib/table")

page_titles = {"voice", "seq", "rhythm", "global"}
column_widths = {8, 30, 30, 30, 30}

voice_header = {"", "mode", "pitch", "level", "offset"}
key_row = true

function init()
    crow.ii.jf.mode(1)

    -- True if the screen should be updated
    is_dirty = true

    -- Active page tab
    selected_page = 1

    min_cells = {
        {2, 3},
        {2, 2},
        {2, 2}
    }

    max_cells = {
        {7, 5},
        {3, 5},
        {5, 4}
    }

    -- Active cell on each page with a table
    selected_cells = {
        {2, 3},
        {2, 2},
        {2, 2}
    }

    -- True if the tempo UI should be shown
    show_tempo = false

    crow.output[1].action = "pulse(0.005, 10)"
    sh = Subharmonicon.new {
        play_voice = crow.ii.jf.play_voice,
        trigger_env_gen = crow.output[1]
    }

    -- sh:start()

    -- Screen refresh loop
    clock.run(
        function()
            while true do
                redraw()
                clock.sleep(1 / 15)
            end
        end
    )
end

function cleanup()
    sh:stop()
    crow.ii.jf.play_voice(0, 0, 0)
    crow.ii.jf.mode(0)
end

clock.transport.start = function()
    sh:start()
end

clock.transport.stop = function()
    sh:stop()
end

function keyboard.char(c)
    if c == "w" then
        update_cell(-1, 0)
    elseif c == "a" then
        update_cell(0, -1)
    elseif c == "s" then
        update_cell(1, 0)
    elseif c == "d" then
        update_cell(0, 1)
    elseif c == "A" then
        selected_page = util.clamp(selected_page - 1, 1, #page_titles)
    elseif c == "D" then
        selected_page = util.clamp(selected_page + 1, 1, #page_titles)
    end
end

function keyboard.code(key, value)
    if value ~= 1 then
        return
    end

    local d = 0
    if key == "UP" then
        d = keyboard.shift() and 10 or 1
    elseif key == "DOWN" then
        d = keyboard.shift() and -10 or -1
    else
        return
    end

    if selected_page == 1 then
        update_voice(d)
    elseif selected_page == 2 then
        update_seq(d)
    elseif selected_page == 3 then
        update_rhythm(d)
    end
end

function key(n, z)
    if n == 1 then
        show_tempo = z == 1
        is_dirty = true
    elseif z == 1 then
        if n == 2 then
            if key_row then
                update_cell(-1, 0)
            else
                update_cell(0, -1)
            end
        else
            if key_row then
                update_cell(1, 0)
            else
                update_cell(0, 1)
            end
        end
    end
    is_dirty = true
end

function update_cell(dy, dx)
    local min_cell = min_cells[selected_page]
    local max_cell = max_cells[selected_page]
    local cell = selected_cells[selected_page]
    cell[1] = util.clamp(cell[1] + dy, min_cell[1], max_cell[1])
    cell[2] = util.clamp(cell[2] + dx, min_cell[2], max_cell[2])
end

function sign(n)
    if n > 0 then
        return 1
    elseif n < 0 then
        return -1
    else
        return 0
    end
end

function enc(n, d)
    if n == 1 then
        if show_tempo then
            local tempo = clock.get_tempo()
            params:set("clock_tempo", tempo + d)
        else
            selected_page = util.clamp(selected_page + d, 1, #page_titles)
        end
    elseif n == 2 then
        if key_row then
            update_cell(0, sign(d))
        else
            update_cell(sign(d), 0)
        end
    elseif n == 3 then
        if selected_page == 1 then
            update_voice(d)
        elseif selected_page == 2 then
            update_seq(d)
        elseif selected_page == 3 then
            update_rhythm(d)
        end
    end
    is_dirty = true
end

function update_voice(d)
    local cell = selected_cells[1]
    local row, col = cell[1], cell[2]
    local index = row - 1
    local voice = sh:get_voice(index)

    if col == 3 then
        local is_main = index == voice.main
        if is_main then
            voice.offset = util.clamp(voice.offset + d, -60, 67)
        else
            voice.subdivision = util.clamp(voice.subdivision + d, 1, 16)
        end
    elseif col == 4 then
        voice.level = util.clamp(voice.level + d / 10, 0, 10)
    elseif col == 5 then
        local seq = sh:get_sequencer(voice.seq)
        seq.targets[voice.target] = d > 0
    end
end

function update_seq(d)
    local cell = selected_cells[2]
    local row, col = cell[1], cell[2]
    local index = row - 1
    local seq = sh:get_sequencer(index)
    local step_index = col - 1
    local step = seq.steps[step_index]
    local step_range = sh:get_step_range()
    seq.steps[step_index] = util.clamp(step + d, -step_range, step_range)
end

function update_rhythm(d)
    local cell = selected_cells[3]
    local row, col = cell[1], cell[2]
    local index = row - 1
    local gen = sh:get_rhythm_generator(index)

    if col == 2 then
        gen.subdivision = util.clamp(gen.subdivision + d, 1, 16)
    elseif col == 3 then
        gen.targets[1] = d > 0
    elseif col == 4 then
        gen.targets[2] = d > 0
    end
end

function redraw()
    -- if not is_dirty then
    --     return
    -- end
    is_dirty = false

    screen.clear()
    screen.aa(0)

    if show_tempo then
        Page.redraw({"tempo", "", "", ""}, 1)
        local tempo = string.format("%.0f", clock.get_tempo())
        local tempo_width = screen.text_extents(tempo)
        screen.move(32 + (32 - tempo_width) // 2, 6)
        screen.level(15)
        screen.text(tempo)
    else
        Page.redraw(page_titles, selected_page)
    end

    if selected_page == 1 then
        redraw_voice_page()
    elseif selected_page == 2 then
        redraw_seq_page()
    elseif selected_page == 3 then
        redraw_rhythm_page()
    end

    screen.update()
end

function redraw_voice_page()
    local data = get_voice_table_data()
    local cell = selected_cells[1]
    Table.redraw(0, 16, data, column_widths, cell[1], cell[2])
end

function get_voice_table_data()
    local data = {
        {"", "mode", "pitch", "level", "offset"}
    }
    for i = 1, 6 do
        local voice = sh:get_voice(i)
        local is_main = i == voice.main
        local mode = is_main and "vco" or "sub"
        local pitch = is_main and fmt_offset(voice.offset) or fmt_subdivision(voice.subdivision)
        local level = string.format("%.1f", voice.level)
        local sequencer = sh:get_sequencer(voice.seq)
        local is_target = sequencer.targets[voice.target]
        local offset = is_target and ("seq " .. voice.seq) or "-"
        table.insert(data, {i, mode, pitch, level, offset})
    end
    return data
end

function fmt_offset(n)
    local prefix = ""
    if n > 0 then
        prefix = "+"
    end
    return prefix .. n
end

function fmt_subdivision(n)
    return "/" .. n
end

function redraw_seq_page()
    local data = get_seq_table_data()
    local cell = selected_cells[2]
    Table.redraw(0, 16, data, column_widths, cell[1], cell[2])
end

function get_seq_table_data()
    local data = {
        {"", "1", "2", "3", "4"}
    }
    for i = 1, 2 do
        local row = {i}
        local seq = sh:get_sequencer(i)
        for j = 1, 4 do
            local step = fmt_offset(seq.steps[j])
            table.insert(row, step)
        end
        table.insert(data, row)
    end
    return data
end

function redraw_rhythm_page()
    local data = get_rhythm_table_data()
    local cell = selected_cells[3]
    Table.redraw(0, 16, data, column_widths, cell[1], cell[2])
end

function get_rhythm_table_data()
    local data = {
        {"", "div", "seq1", "seq2"}
    }
    for i = 1, 4 do
        local gen = sh:get_rhythm_generator(i)
        local sub = fmt_subdivision(gen.subdivision)
        local seq1 = gen.targets[1] and "x" or "-"
        local seq2 = gen.targets[2] and "x" or "-"
        table.insert(data, {i, sub, seq1, seq2})
    end
    return data
end
