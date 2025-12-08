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
	{text = "he/him", weight = 150, color = G.C.BLUE},
	{text = "she/her", weight = 150, color = blend(G.C.RED, G.C.WHITE)},
	{text = "they/them", weight = 30, color = G.C.PURPLE},
	{text = "he/they", weight = 50, color = blend(G.C.BLUE, G.C.GREY)},
	{text = "she/they", weight = 50, color = blend(G.C.RED, G.C.GREY)},
	{text = "he/she", weight = 10, color = blend(G.C.BLUE, G.C.RED)},
	{text = "she/he", weight = 10, color = blend(G.C.BLUE, G.C.RED)},
	{text = "he/she/they", weight = 15, color = blend(G.C.PURPLE, G.C.GREY)},
	{text = "any/all", weight = 7, color = G.C.UI.TEXT_INACTIVE},
	{text = "it/its", weight = 7, color = G.C.IMPORTANT},
	{text = "xe/xem", weight = 5, color = G.C.PALE_GREEN},
	{text = "xe/they", weight = 3, color = blend(G.C.PALE_GREEN, G.C.GREY)},
	{text = "he/it", weight = 5, color = blend(G.C.BLUE, G.C.BLACK)},
	{text = "she/it", weight = 5, color = blend(G.C.RED, G.C.BLACK)},
	{text = "they/it", weight = 7, color = blend(G.C.PURPLE, G.C.BLACK)},
	{text = "no pronouns", weight = 7, color = G.C.BLACK},
	{text = "he/xem", weight = 3, color = blend(G.C.BLUE, G.C.PALE_GREEN)},
	{text = "they/any", weight = 10, color = blend(G.C.PURPLE, G.C.WHITE)},
}

function JOKERPRONOUNS.inject_custom_pronouns()
	-- Cross-mod entrypoint 1/2
	-- Pronouns are of one of these two structures:
	-- {text = string, weight = number, color = Color, text_color = Color?}
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
local pronouns_by_text = {}
for i, value in ipairs(JOKERPRONOUNS.weighted_pronoun_table) do
	local tbl = {
		text = value.text,
		ref_table = value.ref_table,
		ref_value = value.ref_value,
		weight = value.weight / weight_sum,
		color = value.color,
		text_color = value.text_color
	}
	normalized_pronoun_table[i] = tbl
	if tbl.text then
		pronouns_by_text[value.text] = tbl
	end
end

-- LuaJIT simple implementation of SeaHash.

local A = 0x16f11fe89b0d677cULL -- Starting seed of section 1
local B = 0xb480a793d8e6c86cULL -- Starting seed of section 2
local C = 0x6fe2e5aaf078ebc9ULL -- Starting seed of section 3
local D = 0x14f994a4c5259381ULL -- Starting seed of section 4
local P = 0x07ed0e9fa0d94a33ULL -- Multiplier for j(x)

local function h(x)
	return bit.lshift(bit.lshift(x, 32ULL), bit.lshift(x, 60ULL))
end
local function j(x)
	return P * x
end
local function g(x)
	return j(h(j(x)))
end

local hash_cache = {}

function hash(str)
	if hash_cache[str] then return hash_cache[str] end
	while ((#str) % 8) ~= 0 do
		str = str .. "\0"
	end
	local LEN = #str
	local bytebuf = 0ULL
	local a, b, c, d = A, B, C, D
	local i = 1
	while true do
		if i + 7 > #str then break end
		bytebuf = bit.bor(
			bit.tobit(str:byte(i)),
			bit.lshift(bit.tobit(str:byte(i+1)), 8),
			bit.lshift(bit.tobit(str:byte(i+2)), 16),
			bit.lshift(bit.tobit(str:byte(i+3)), 24),
			bit.lshift(bit.tobit(str:byte(i+4)), 32),
			bit.lshift(bit.tobit(str:byte(i+5)), 40),
			bit.lshift(bit.tobit(str:byte(i+6)), 48),
			bit.lshift(bit.tobit(str:byte(i+7)), 56)
		)
		a, b, c, d = b, c, d, g(bit.bxor(a, bytebuf))
		i = i + 8
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
	return normalized_pronoun_table[i]
end

function JOKERPRONOUNS.get_pronouns(card)
	local pronouns = {text = "???/???", weight = 0, color = G.C.BLACK}
	if card.ability and card.ability.pronouns then
		-- Cross-mod entrypoint 2/2
		-- See above
		if type(card.ability.pronouns) == "string" then
			if pronouns_by_text[card.ability.pronouns] then
				return pronouns_by_text[card.ability.pronouns]
			else
				return {text = card.ability.pronouns, weight = 0, color = G.C.BLACK}
			end
		else
			return card.ability.pronouns
		end
	else
		local key = card.config.center_key or
			card.config.key or 
			(card.config.tag and card.config.tag.key)
		if not key then
			print(card.config)
			return
		end
		if key == "c_base" then return end
		if key:find("^m_") then return end
		if key:find("^e_") then return end
		local key_hash = hash(key)
		local rand = tonumber(bit.rshift(key_hash, 32)) / 2^32
		return pick_random(rand)
	end
end

local Game_start_up = Game.start_up

local misprint_pronouns = {
	"eh/ihm",
	"eh/ihm",
	"eh/ihm",
	"eh/ihm",
	"eh/ihm",
	"hse/ehr",
	"hse/ehr",
	"hse/ehr",
	"hse/ehr",
	"hse/ehr",
	"htye/emht",
	"htye/emht",
	"tis/it",
	"tis/it",
	"ex/mxe",
	"nay/lal",
	"oeno",
	"ouospr nnno"
}

function Game:start_up()
	Game_start_up(self)
	G.P_CENTERS["j_joker"].config.pronouns = "any/all"
	G.P_CENTERS["j_misprint"].config.pronouns = {
		ref_table = setmetatable({}, {__index = function()
			return misprint_pronouns[math.random(#misprint_pronouns)]
		end}),
		ref_value = "*",
		color = {1, 0, 1, 1},
	}
	G.P_CENTERS["j_invisible"].config.pronouns = "no pronouns"
end

