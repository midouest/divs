local Page = {}

function Page.redraw(pages, selected_index)
    screen.move(0, 8)
    screen.line_width(1)
    screen.line_rel(128, 0)
    screen.level(1)
    screen.stroke()

    local num_pages = #pages
    local page_width = 128 // num_pages
    local page_height = 8
    local x0 = (128 - page_width * num_pages) // 2
    local y0 = 0

    for i = 1, num_pages do
        local x = x0 + (i - 1) * page_width
        local y = y0
        local title = pages[i]
        local is_selected = i == selected_index

        if is_selected then
            screen.level(15)
            screen.rect(x, y, page_width, page_height)
            screen.fill()
        end

        local title_width, title_height = screen.text_extents(title)
        local title_x = x + (page_width - title_width) // 2
        local title_y = y + 6
        screen.move(title_x, title_y)
        local text_level = is_selected and 0 or 15
        screen.level(text_level)
        screen.text(title)
    end
end

return Page
