local Table = {}

function Table.redraw(x0, y0, data, column_widths, selected_row_index, selected_col_index)
    screen.line_width(1)
    screen.level(1)
    screen.move(x0, y0 + 2)
    screen.line_rel(128, 0)
    screen.stroke()

    local y = y0
    local row_height = 8
    for row_index = 1, #data do
        local row = data[row_index]
        local x = x0

        -- if row_index == selected_row_index then
        --     screen.level(1)
        --     screen.rect(x, y - 6, 128, 7)
        --     screen.fill()
        -- end

        -- local is_row_selected = row_index == selected_row_index
        for col_index = 1, #data[row_index] do
            if row_index == selected_row_index and col_index == selected_col_index then
                screen.level(2)
                screen.rect(x, y - 6, column_widths[col_index], 7)
                screen.fill()
            end

            screen.level(15)
            screen.move(x, y)
            local cell = row[col_index]
            screen.text(cell)
            x = x + column_widths[col_index]
        end

        y = y + row_height
    end
end

return Table
