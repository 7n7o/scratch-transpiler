-- full, self-contained LCG optimizer using discrete hill climbing nya~ :3
-- this actually *moves* parameters, unlike fake gradients >.<

---------------- RNG + TESTING ----------------

local function lcg(state, a, c, m)
    return function()
        state = (a * state + c) % m
        return state / m
    end
end

local function test_rng(rng_fn, samples, bins)
    samples = samples or 60000
    bins = bins or 100

    local hist = {}
    for i = 1, bins do hist[i] = 0 end

    local sum, sumsq = 0, 0
    local prev, serial = nil, 0

    for i = 1, samples do
        local x = rng_fn()
        if x < 0 then x = 0 elseif x >= 1 then x = 1 - 1e-15 end

        sum = sum + x
        sumsq = sumsq + x * x

        local b = math.floor(x * bins) + 1
        hist[b] = hist[b] + 1

        if prev then serial = serial + prev * x end
        prev = x
    end

    local mean = sum / samples
    local var = (sumsq / samples) - mean * mean

    local expected = samples / bins
    local chi2 = 0
    for i = 1, bins do
        local d = hist[i] - expected
        chi2 = chi2 + (d * d) / expected
    end

    local serial_corr = (serial / (samples - 1) - mean * mean) / var

    return {
        mean = mean,
        variance = var,
        chi_squared = chi2,
        serial_correlation = serial_corr
    }
end

---------------- SCORING ----------------

local IDEAL_MEAN = 0.5
local IDEAL_VAR  = 1/12

local function score_stats(s, bins)
    return
        math.abs(s.mean - IDEAL_MEAN) * 2
      + math.abs(s.variance - IDEAL_VAR) * 2
      + math.abs(s.chi_squared - (bins - 1)) / (bins - 1)
      + math.abs(s.serial_correlation) * 2.5
end

---------------- OPTIMIZER ----------------

local m = 2^48          -- clean power-of-two modulus nya~
local state0 = 123456789
local bins = 100
local samples = 60000

local function score_lcg(a, c)
    local rng = lcg(state0, a, c, m)
    local stats = test_rng(rng, samples, bins)
    return score_stats(stats, bins)
end



local deltas = { -4096, -257, -17, -1, 1, 17, 257, 4096 }
local global_best_score = math.huge
local global_a, global_c = nil, nil

local a = 1401453
local c = 1014168361
local best_score = score_lcg(a, c)

for iter = 1, 40 do
    local improved = false

    for _, da in ipairs(deltas) do
        for _, dc in ipairs(deltas) do
            local na = math.max(1, a + da)
            local nc = math.max(1, c + dc)
            if nc % 2 == 0 then nc = nc + 1 end

            local s = score_lcg(na, nc)

            -- update local best
            if s < best_score then
                a, c = na, nc
                best_score = s
                improved = true
            end

            -- update global best
            if s < global_best_score then
                global_best_score = s
                global_a, global_c = na, nc
            end
        end
    end

    print(string.format(
        "iter %02d | local %.6f | global %.6f | a %d | c %d",
        iter, best_score, global_best_score, a, c
    ))

    if not improved then
        -- hop, but DON'T forget the global champion
        a = global_a + math.random(-100000, 100000)
        c = global_c + math.random(-100000, 100000)
        if c % 2 == 0 then c = c + 1 end
        best_score = score_lcg(a, c)
    end
end

print("true best ever found nya~ //w//")
print("a =", global_a)
print("c =", global_c)
print("score =", global_best_score)