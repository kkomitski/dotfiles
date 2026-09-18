require "nvchad.mappings"

local map = vim.keymap.set
local all_modes = { "n", "i", "v" }

local function run(command)
	return function()
		vim.cmd(command)
	end
end

local function save()
	vim.cmd "write"
end
local function terminal_sequence(number)
	return string.format("\27[%d~", number)
end

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- VSCode file navigation.
local function find_files()
	vim.cmd "Telescope find_files"
end

local function command_palette()
	vim.cmd "Telescope commands"
end

local function current_buffer_search()
	vim.cmd "Telescope current_buffer_fuzzy_find"
end

local function search_files()
	vim.cmd "Telescope live_grep"
end

local function toggle_explorer()
	vim.cmd "NvimTreeToggle"
end

map(all_modes, "<D-p>", find_files, { desc = "Find files (Cmd+P)" })
map(all_modes, "<C-p>", find_files, { desc = "Find files (Ctrl+P)" })
map(all_modes, "<D-P>", command_palette, { desc = "Command palette (Cmd+Shift+P)" })
map(all_modes, "<C-S-p>", command_palette, { desc = "Command palette (Ctrl+Shift+P)" })
map(all_modes, "<D-j>", current_buffer_search, { desc = "Fuzzy find in file (Cmd+J)" })
map(all_modes, "<C-j>", current_buffer_search, { desc = "Fuzzy find in file (Ctrl+J)" })
map(all_modes, "<D-F>", search_files, { desc = "Find in files (Cmd+Shift+F)" })
map(all_modes, "<C-S-f>", search_files, { desc = "Find in files (Ctrl+Shift+F)" })
map(all_modes, "<D-b>", toggle_explorer, { desc = "Toggle explorer (Cmd+B)" })
map(all_modes, "<C-b>", toggle_explorer, { desc = "Toggle explorer (Ctrl+B)" })
map(all_modes, terminal_sequence(24), find_files, { desc = "Find files (Cmd+P)" })
map(all_modes, terminal_sequence(25), command_palette, { desc = "Command palette (Cmd+Shift+P)" })
map(all_modes, terminal_sequence(26), search_files, { desc = "Find in files (Cmd+Shift+F)" })

local function open_buffer(index)
	local buffers = vim.tbl_filter(function(buffer)
		return buffer.listed == 1
	end, vim.fn.getbufinfo())
	local buffer = buffers[index]

	if buffer then
		vim.api.nvim_set_current_buf(buffer.bufnr)
	else
		vim.notify(("No open editor at index %d"):format(index), vim.log.levels.INFO)
	end
end
local function select_tab(index)
	if vim.fn.tabpagenr("$") >= index then
		vim.cmd("tabnext " .. index)
	end
end


for index = 1, 5 do
	map(all_modes, "<D-" .. index .. ">", function()
		select_tab(index)
	end, { desc = "Select Neovim tab " .. index })
	map(all_modes, "<C-" .. index .. ">", function()
		open_buffer(index)
	end, { desc = "Open editor " .. index })
end
for index = 1, 5 do
	map(all_modes, terminal_sequence(55 + index), function()
		open_buffer(index)
	end, { desc = "Open editor " .. index })
end

local function focus_window(index)
	local windows = vim.api.nvim_list_wins()
	if windows[index] then
		vim.api.nvim_set_current_win(windows[index])
	end
end

for index = 1, 3 do
	map(all_modes, "<D-S-" .. index .. ">", function()
		focus_window(index)
	end, { desc = "Focus editor group " .. index })
	map(all_modes, "<C-S-" .. index .. ">", function()
		focus_window(index)
	end, { desc = "Focus editor group " .. index })
end
for index = 1, 3 do
	map(all_modes, terminal_sequence(52 + index), function()
		focus_window(index)
	end, { desc = "Focus editor group " .. index })
end

map(all_modes, "<D-t>", run "vsplit", { desc = "New editor group right (Cmd+T)" })
map(all_modes, "<C-t>", run "vsplit", { desc = "New editor group right (Ctrl+T)" })

local function open_recent()
	vim.cmd "Telescope oldfiles"
end

map("n", "<D-r>", open_recent, { desc = "Open recent (Cmd+R)" })
map("n", "<C-r>", open_recent, { desc = "Open recent (Ctrl+R)" })

-- Save behavior matches the profile's Cmd+S insert-mode binding, with a Ctrl fallback.
map({ "n", "i", "v" }, "<D-s>", save, { desc = "Save" })
map({ "n", "i", "v" }, "<C-s>", save, { desc = "Save" })

-- Toggle the bottom terminal.
local function toggle_terminal()
	vim.cmd "ToggleTerm"
end

map("n", "<C-`>", toggle_terminal, { desc = "Toggle terminal" })
map("t", "<C-`>", toggle_terminal, { desc = "Toggle terminal" })
map({ "n", "t" }, "<C-\\>", toggle_terminal, { desc = "Toggle terminal (Ctrl+\\)" })

-- DAP equivalents for the profile's debug chord and REPL shortcut.
local function continue_debugging()
	local ok, dap = pcall(require, "dap")
	if ok then
		dap.continue()
	else
		vim.notify("nvim-dap is not available", vim.log.levels.WARN)
	end
end

local function toggle_debug_repl()
	local ok, dap = pcall(require, "dap")
	if ok then
		dap.repl.toggle()
	else
		vim.notify("nvim-dap is not available", vim.log.levels.WARN)
	end
end

map("n", "<D-d><D-b>", continue_debugging, { desc = "Start debugging (Cmd+D Cmd+B)" })
map("n", "<C-d><C-b>", continue_debugging, { desc = "Start debugging (Ctrl+D Ctrl+B)" })
map("n", "<C-S-`>", toggle_debug_repl, { desc = "Toggle debug REPL" })
map("n", terminal_sequence(52), continue_debugging, { desc = "Start debugging (Cmd+D Cmd+B)" })

-- Comment actions.
local function toggle_comment()
	local ok, api = pcall(require, "Comment.api")
	if ok then
		api.toggle.linewise.current()
	else
		vim.cmd "normal! gcc"
	end
end

local function toggle_visual_comment()
	local visual_mode = vim.fn.visualmode()
	local ok, api = pcall(require, "Comment.api")
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, false, true), "n", false)

	if ok then
		api.toggle.linewise(visual_mode)
	else
		vim.cmd "normal! gc"
	end
end

local function duplicate_and_comment()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	vim.cmd "normal! yyp"
	vim.api.nvim_win_set_cursor(0, { line, 0 })
	toggle_comment()
	vim.api.nvim_win_set_cursor(0, { line + 1, 0 })
end

map("n", "<D-/>", toggle_comment, { desc = "Toggle comment (Cmd+/)" })
map("v", "<D-/>", toggle_visual_comment, { desc = "Toggle comment (Cmd+/)" })
map("n", "<C-/>", toggle_comment, { desc = "Toggle comment (Ctrl+/)" })
map("v", "<C-/>", toggle_visual_comment, { desc = "Toggle comment (Ctrl+/)" })
map("n", "<D-C-/>", duplicate_and_comment, { desc = "Duplicate and comment (Ctrl+Cmd+/)" })
map("n", "<C-M-/>", duplicate_and_comment, { desc = "Duplicate and comment (Ctrl+Alt+/)" })
map("n", terminal_sequence(44), toggle_comment, { desc = "Toggle comment (Cmd+/)" })
map("v", terminal_sequence(44), toggle_visual_comment, { desc = "Toggle comment (Cmd+/)" })
map("n", terminal_sequence(51), duplicate_and_comment, { desc = "Duplicate and comment (Ctrl+Cmd+/)" })

-- VSCode transform-case commands.
local function words(text)
	local result = {}
	for word in text:gmatch "[%w]+" do
		result[#result + 1] = word:lower()
	end
	return result
end

local function capitalize(word)
	return word:sub(1, 1):upper() .. word:sub(2):lower()
end

local case_transforms = {
	lower = function(text)
		return text:lower()
	end,
	upper = function(text)
		return text:upper()
	end,
	camel = function(text)
		local parts = words(text)
		if #parts == 0 then
			return text
		end
		local result = parts[1]
		for index = 2, #parts do
			result = result .. capitalize(parts[index])
		end
		return result
	end,
	pascal = function(text)
		local result = {}
		for _, word in ipairs(words(text)) do
			result[#result + 1] = capitalize(word)
		end
		return table.concat(result)
	end,
	snake = function(text)
		return table.concat(words(text), "_")
	end,
	kebab = function(text)
		return table.concat(words(text), "-")
	end,
	title = function(text)
		local result = {}
		for _, word in ipairs(words(text)) do
			result[#result + 1] = capitalize(word)
		end
		return table.concat(result, " ")
	end,
}

local function transform_selection(kind)
	if vim.fn.mode():sub(1, 1) == "n" then
		vim.cmd "normal! viw"
	end

	local start = vim.fn.getpos "'<"
	local finish = vim.fn.getpos "'>"
	if start[2] == 0 or finish[2] == 0 then
		return
	end

	local start_row = start[2] - 1
	local finish_row = finish[2] - 1
	local start_line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1] or ""
	local finish_line = vim.api.nvim_buf_get_lines(0, finish_row, finish_row + 1, false)[1] or ""
	local start_col = math.min(math.max(start[3] - 1, 0), #start_line)
	local finish_col = math.min(math.max(finish[3], 0), #finish_line)
	if vim.fn.visualmode() == "V" then
		start_col = 0
		finish_col = #finish_line
	end

	local selected = vim.api.nvim_buf_get_text(0, start_row, start_col, finish_row, finish_col, {})
	local transformed = case_transforms[kind](table.concat(selected, "\n"))
	local replacement = vim.split(transformed, "\n", { plain = true })
	vim.api.nvim_buf_set_text(0, start_row, start_col, finish_row, finish_col, replacement)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, false, true), "n", false)
end

local function map_case(kind, command_key, terminal_key, ghostty_key)
	local callback = function()
		transform_selection(kind)
	end
	map({ "n", "v" }, command_key, callback, { desc = "Transform selection to " .. kind })
	map({ "n", "v" }, terminal_key, callback, { desc = "Transform selection to " .. kind })
	map({ "n", "v" }, ghostty_key, callback, { desc = "Transform selection to " .. kind })
end

map_case("camel", "<C-D-m>", "<C-M-m>", terminal_sequence(45))
map_case("pascal", "<C-D-p>", "<C-M-p>", terminal_sequence(48))
map_case("snake", "<D-S-s>", "<C-M-S-s>", terminal_sequence(42))
map_case("kebab", "<C-D-h>", "<C-M-h>", terminal_sequence(49))
map_case("title", "<C-D-c>", "<C-M-S-c>", terminal_sequence(50))
map_case("upper", "<C-D-u>", "<C-M-u>", terminal_sequence(46))
map_case("lower", "<C-D-l>", "<C-M-l>", terminal_sequence(47))

-- macOS editor actions. WezTerm and Ghostty route these Command shortcuts below.
local function select_all()
	vim.cmd "normal! ggVG"
end

map("n", "<D-a>", select_all, { desc = "Select all" })
map("i", "<D-a>", function()
	vim.cmd "normal! ggVG"
end, { desc = "Select all" })
map("v", "<D-a>", select_all, { desc = "Select all" })
map("n", "<D-A>", select_all, { desc = "Select all" })
map("i", "<D-A>", select_all, { desc = "Select all" })
map("v", "<D-A>", select_all, { desc = "Select all" })
map("n", "<C-M-a>", select_all, { desc = "Select all" })
map("i", "<C-M-a>", select_all, { desc = "Select all" })
map("v", "<C-M-a>", select_all, { desc = "Select all" })
map(all_modes, terminal_sequence(35), select_all, { desc = "Select all" })

local function undo()
	vim.cmd "undo"
end

local function redo()
	vim.cmd "redo"
end

map({ "n", "i" }, "<D-z>", undo, { desc = "Undo" })
map({ "n", "i" }, "<D-Z>", redo, { desc = "Redo" })
map({ "n", "i" }, "<C-M-z>", undo, { desc = "Undo" })
map({ "n", "i" }, "<C-M-S-z>", redo, { desc = "Redo" })
map({ "n", "i" }, terminal_sequence(39), undo, { desc = "Undo" })
map({ "n", "i" }, terminal_sequence(40), redo, { desc = "Redo" })

map("v", "<D-c>", '"+y', { desc = "Copy" })
map("n", "<D-c>", '"+yy', { desc = "Copy line" })
map("v", "<D-x>", '"+d', { desc = "Cut" })
map("n", "<D-x>", '"+dd', { desc = "Cut line" })
map("n", "<D-v>", '"+p', { desc = "Paste" })
map("v", "<D-v>", '"+p', { desc = "Paste" })
map("i", "<D-v>", "<C-r>+", { desc = "Paste" })
map("v", "<C-M-c>", '"+y', { desc = "Copy" })
map("n", "<C-M-c>", '"+yy', { desc = "Copy line" })
map("v", "<C-M-x>", '"+d', { desc = "Cut" })
map("n", "<C-M-x>", '"+dd', { desc = "Cut line" })
map("n", "<C-M-v>", '"+p', { desc = "Paste" })
map("v", "<C-M-v>", '"+p', { desc = "Paste" })
map("i", "<C-M-v>", "<C-r>+", { desc = "Paste" })
map("v", terminal_sequence(36), '"+y', { desc = "Copy" })
map("n", terminal_sequence(36), '"+yy', { desc = "Copy line" })
map("v", terminal_sequence(37), '"+d', { desc = "Cut" })
map("n", terminal_sequence(37), '"+dd', { desc = "Cut line" })
map("n", terminal_sequence(38), '"+p', { desc = "Paste" })
map("v", terminal_sequence(38), '"+p', { desc = "Paste" })
map("i", terminal_sequence(38), "<C-r>+", { desc = "Paste" })

-- Problems panel equivalent.
map("n", "<D-S-m>", run "Trouble diagnostics toggle", { desc = "Diagnostics" })
map("n", "<C-S-m>", run "Trouble diagnostics toggle", { desc = "Diagnostics" })
map("n", terminal_sequence(43), run "Trouble diagnostics toggle", { desc = "Diagnostics" })

-- Test Explorer equivalents for Jest.
local function test_action(action)
	return function()
		local ok, neotest = pcall(require, "neotest")
		if ok then
			action(neotest)
		else
			vim.notify("neotest is not available", vim.log.levels.WARN)
		end
	end
end

map("n", "<leader>tr", test_action(function(neotest)
	neotest.run.run()
end), { desc = "Run nearest test" })
map("n", "<leader>tf", test_action(function(neotest)
	neotest.run.run(vim.fn.expand "%")
end), { desc = "Run file tests" })
map("n", "<leader>ts", test_action(function(neotest)
	neotest.summary.toggle()
end), { desc = "Toggle test summary" })
map("n", "<leader>to", test_action(function(neotest)
	neotest.output.open { enter = true }
end), { desc = "Open test output" })

-- GitLens/Git Graph equivalents.
map("n", "<leader>gg", run "Git", { desc = "Git status" })
map("n", "<leader>gd", run "DiffviewOpen", { desc = "Open Git diff view" })
map("n", "<leader>gh", run "DiffviewFileHistory", { desc = "Open Git file history" })
