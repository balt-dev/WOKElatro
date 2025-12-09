JOKERPRONOUNS = {}

local function blend(a, b, weight)
	weight = weight or 0.5
	return {
		a[1]*(1-weight)+b[1]*weight,
		a[2]*(1-weight)+b[2]*weight,
		a[3]*(1-weight)+b[3]*weight,
		a[4]*(1-weight)+b[4]*weight
	}
end

JOKERPRONOUNS.weighted_pronoun_table = {
	{key = "pn_he_him",      weight = 150, color = G.C.BLUE},
	{key = "pn_she_her",     weight = 150, color = blend(G.C.RED, G.C.WHITE)},
	{key = "pn_they_them",   weight = 30, color = G.C.PURPLE},
	{key = "pn_he_they",     weight = 50, color = blend(G.C.BLUE, G.C.GREY)},
	{key = "pn_she_they",    weight = 50, color = blend(G.C.RED, G.C.GREY)},
	{key = "pn_he_she",      weight = 10, color = blend(G.C.BLUE, G.C.RED)},
	{key = "pn_she_he",      weight = 10, color = blend(G.C.BLUE, G.C.RED)},
	{key = "pn_he_she_they", weight = 15, color = blend(G.C.PURPLE, G.C.GREY)},
	{key = "pn_any_all",     weight = 7, color = G.C.UI.TEXT_INACTIVE},
	{key = "pn_it_its",      weight = 7, color = G.C.IMPORTANT},
	{key = "pn_xe_xem",      weight = 5, color = G.C.PALE_GREEN},
	{key = "pn_xe_they",     weight = 3, color = blend(G.C.PALE_GREEN, G.C.GREY)},
	{key = "pn_he_it",       weight = 5, color = blend(G.C.BLUE, G.C.BLACK)},
	{key = "pn_she_it",      weight = 5, color = blend(G.C.RED, G.C.BLACK)},
	{key = "pn_they_it",     weight = 7, color = blend(G.C.PURPLE, G.C.BLACK)},
	{key = "pn_no_pronouns", weight = 7, color = G.C.BLACK},
	{key = "pn_he_xem",      weight = 3, color = blend(G.C.BLUE, G.C.PALE_GREEN)},
	{key = "pn_they_any",    weight = 10, color = blend(G.C.PURPLE, G.C.WHITE)},
}

function JOKERPRONOUNS.inject_custom_pronouns()
	-- Cross-mod entrypoint 1/2
	-- Pronouns are of one of these two structures:
	-- {key = string, weight = number, color = Color, text_color = Color?}
	-- {ref_table = table, ref_value = any, weight = number, color = Color, text_color = Color?}
	
	-- table.insert(JOKERPRONOUNS.weighted_pronoun_table, 
	-- 	 {ref_table = {thing="Jim/bo"}, ref_value = "thing", weight = 200, color = G.C.WHITE, text_color = G.C.BLACK}
	-- )
end

JOKERPRONOUNS.inject_custom_pronouns()

local weight_sum = 0
for _, p in ipairs(JOKERPRONOUNS.weighted_pronoun_table) do
	weight_sum = weight_sum + p.weight
end

local normalized_pronoun_table = {}
local pronouns_by_key = {}
for i, value in ipairs(JOKERPRONOUNS.weighted_pronoun_table) do
	local tbl = {
		key = value.key,
		ref_table = value.ref_table,
		ref_value = value.ref_value,
		weight = value.weight / weight_sum,
		color = value.color,
		text_color = value.text_color
	}
	normalized_pronoun_table[i] = tbl
	if tbl.key then
		pronouns_by_key[value.key] = tbl
	end
end

-- LuaJIT simple implementation of SeaHash, altered for 32-bit numbers. Might be not as good.

local A = 0x9b0d677c
local B = 0xd8e6c86c
local C = 0xf078ebc9
local D = 0xc5259381
local P = 0xa0d94a33

local function h(x)
	return bit.lshift(bit.lshift(x, 16), bit.lshift(x, 28))
end
local function j(x)
	return bit.tobit(P * x)
end
local function g(x)
	return j(h(j(x)))
end

local hash_cache = {}

function hash(str)
	if hash_cache[str] then return hash_cache[str] end
	while ((#str) % 4) ~= 0 do
		str = str .. "\0"
	end
	local LEN = #str
	local bytebuf = 0
	local a, b, c, d = A, B, C, D
	local i = 1
	while true do
		if i + 3 > #str then break end
		bytebuf = bit.bor(
			str:byte(i),
			bit.lshift(str:byte(i+1), 8),
			bit.lshift(str:byte(i+2), 16),
			bit.lshift(str:byte(i+3), 24)
		)
		a, b, c, d = b, c, d, g(bit.bxor(a, bytebuf))
		i = i + 4
	end
	local res = bit.bxor(
		a, b, c, d, LEN
	)
	hash_cache[str] = res
	return res
end

-- Inject badges from hashing joker key

local function pick_random(random_value)
	local sum = 0
	for i, v in ipairs(normalized_pronoun_table) do
		sum = sum + v.weight
		if sum > random_value then return v end
	end
	return normalized_pronoun_table[#normalized_pronoun_table]
end

function JOKERPRONOUNS.get_pronouns(card)
	local pronouns = {text = "???_???", weight = 0, color = G.C.BLACK}
	if card.ability and card.ability.pronouns then
		-- Cross-mod entrypoint 2/2
		-- See above
		if type(card.ability.pronouns) == "string" then
			if pronouns_by_key[card.ability.pronouns] then
				return pronouns_by_key[card.ability.pronouns]
			else
				return {key = card.ability.pronouns, weight = 0, color = G.C.BLACK}
			end
		else
			return card.ability.pronouns
		end
	else
		local key = card.config.center_key or
			card.config.key or 
			(card.config.tag and card.config.tag.key)
		if not key then
			return
		end
		if key == "c_base" then return end
		if key:find("^m_") then return end
		if key:find("^e_") then return end
		local key_hash = hash(key)
		local rand = (tonumber(key_hash) / 2^32) + 0.5
		return pick_random(rand)
	end
end

local Game_start_up = Game.start_up

function Game:start_up()	
	Game_start_up(self)
	G.P_CENTERS["j_joker"].config.pronouns = "pn_any_all"
	-- yuri
	G.P_CENTERS["j_blueprint"].config.pronouns = "pn_she_her"
	G.P_CENTERS["j_brainstorm"].config.pronouns = "pn_she_her"
	-- yaoi
	G.P_CENTERS["j_photograph"].config.pronouns = "pn_he_him"
	G.P_CENTERS["j_hanging_chad"].config.pronouns = "pn_he_him"

	G.P_CENTERS["j_misprint"].config.pronouns = {
		ref_table = setmetatable({}, {__index = function()
			local base_pronoun_key = ({
				"pn_he_him", "pn_she_her", "pn_they_them",
				"pn_xe_xem", "pn_any_all", "pn_no_pronouns",
				"pn_it_its", "pn_he_she_they",
			})[math.random(3)]
			local base_pronoun = localize(base_pronoun_key)
			local chars = {}
			for chr in base_pronoun:gmatch "." do chars[#chars + 1] = chr end
			for i = 1, #chars do
				local j = math.random(#chars - i) + i - 1
				chars[i], chars[j] = chars[j], chars[i]
			end
			return table.concat(chars)
		end}),
		ref_value = "*",
		color = {1, 0, 1, 1},
	}

	G.P_CENTERS["j_invisible"].config.pronouns = "pn_no_pronouns"
	G.P_CENTERS["j_baron"].config.pronouns = "pn_he_him"
	G.P_CENTERS["j_half"].config.pronouns = {key="pn_any_", color=G.C.UI.TEXT_INACTIVE}
	G.P_CENTERS["j_abstract"].config.pronouns = "pn_any_all"
	G.P_CENTERS["j_hiker"].config.pronouns = "pn_he_him"

	G.P_CENTERS["j_caino"].config.pronouns = "pn_he_him"
	G.P_CENTERS["j_triboulet"].config.pronouns = "pn_he_him"
	G.P_CENTERS["j_yorick"].config.pronouns = "pn_was_were"
	G.P_CENTERS["j_chicot"].config.pronouns = "pn_he_him"
	G.P_CENTERS["j_perkeo"].config.pronouns = "pn_he_him"
	-- Streamer aliases, to be respectful for them
	G.P_CENTERS["j_turtle_bean"].config.pronouns = "pn_he_him"
	G.P_CENTERS["j_vagabond"].config.pronouns = "pn_he_him"
end

