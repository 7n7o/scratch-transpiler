local file = require('lib.file')
local serpent = require('lib.serpent')
local class = require('lib.class')

local function lookupify(t)
    local n = {}
    for i, v in pairs(t) do n[v] = true end
    return n
end

function table.clone(org) return { unpack(org) } end

function table.merge(...)
    local new = {}
    for _, tbl in ipairs({...}) do
        for _, v in ipairs(tbl) do
            table.insert(new, v)
        end
    end
    
    return new
end

local function map(list, cb)
    local m = table.clone(list)
    for i, v in pairs(m) do m[i] = cb(v, i) end
    return m
end

local SYMBOLS = lookupify {
    "+", "-", "*", "/", "(", ")", ".", ",", "[", "]", "{", "}", "=", "<", ">",
    "|", "&", "!", "#", "^", "%", "@"
}
local OPERATORS = lookupify { "+", "-", "*", "/", "^", "%" }
local NUMBERS = lookupify { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
local KEYWORDS = lookupify {
    "var", -- TODO: remove var (no support)
    "for", "if", "else", "while", "proc", "return", "true", "false",
    "as", "inline",
    -- for asm
    "asm",
    "scratch",
    "list"
    -- types
    -- "i8", "i16", "i32",
    -- "u8", "u16", "u32",
    -- "float", "char",
    -- "bool", "void"
}

local VAR_KEYWORDS = lookupify {
    "var",     --TODO: remove "var"
    "list",
    -- "i16",
    -- "u16",
    -- "u32",
    -- "i32",
    -- "i8",
    -- "u8",
    -- "float",
    -- "char",
    -- "bool",
    -- "void"
}

local CONDS = lookupify { "==", "<", ">", "&&", "||", ">=", "<=", "!=" }

local UNOPS = lookupify { "!", "#", "-", "@" }

local OPCHARS = lookupify { ">", "<", "=", "|", "&", "!", ".", "/", "*" }

local CHARS_ALL = {}
local CHARS_LOWER = {}
local CHARS_UPPER = {}

for i = 97, 122 do CHARS_LOWER[#CHARS_LOWER + 1] = string.char(i) end
CHARS_UPPER = map(table.clone(CHARS_LOWER),
    function(v, i) return string.upper(v) end)
CHARS_ALL = lookupify(table.merge(CHARS_LOWER, CHARS_UPPER, {"_"}))

local lexer = class {
    constructor = function(self, src)
        self.Source = src
        self.Pos = 1
        self.Line = 1
        self.Tokens = {}
    end,
    peek = function(self, n)
        n = n or 0
        local index = self.Pos + n
        local char = string.sub(self.Source, index, index)
        --if char == '\n' then self.Line = self.Line + 1 end
        return char
    end,
    token = function(self, Type, Data, Start, End)
        local t = {
            Type = Type,
            Start = Start,
            End = End,
            Value = Data,
            Line = self.Line,
            Data = tostring(Data)
        }

        return t
    end,
    word = function(self)
        local start = self.Pos
        while true do
            local char = self:peek()
            if not CHARS_ALL[char] and not NUMBERS[char] then break end
            self.Pos = self.Pos + 1
        end
        local s = self.Source:sub(start, self.Pos - 1)
        self.Pos = self.Pos - 1
        local word_type = 'Word'
        if KEYWORDS[s] then word_type = 'Keyword' end
        return self:token(word_type, s, start, self.Pos)
    end,
    number = function(self)
        local n = ''
        local s = self.Pos
        while true do
            local char = self:peek()
            if NUMBERS[char] or char == '.' then
                n = n .. char
            else
                break
            end
            if char == '' then error("Invalid number") end
            self.Pos = self.Pos + 1
        end
        self.Pos = self.Pos - 1
        return self:token('Number', tonumber(n), s, self.Pos)
    end,
    string = function(self, ch)
        local start = self.Pos
        self.Pos = self.Pos + 1
        while true do
            local char = self:peek()
            if char == ch then break end
            self.Pos = self.Pos + 1
        end
        return self:token('String',
            string.sub(self.Source, start + 1, self.Pos - 1),
            start, self.Pos)
    end,
    collect = function(self)
        local tok = {}

        while true do
            local char = self:peek()

            if char == '\n' then self.Line = self.Line + 1 end

            if self.Pos > #self.Source then
                table.insert(tok, self:token('Eof', '', self.Pos, self.Pos))
                break
            end
            if NUMBERS[char] then
                local t = self:number()
                table.insert(tok, t)
            elseif char == '-' and NUMBERS[self:peek(1)] then
                local t = char
                self.Pos = self.Pos + 1
                local d = self:number()
                local real = tonumber(string.format('%s%s', t, d.Value))
                d.Value = real
                d.Data = tostring(real)
                table.insert(tok, d)
            elseif CHARS_ALL[char] then
                local t = self:word()
                table.insert(tok, t)
            elseif SYMBOLS[char] then
                if OPCHARS[char] then
                    local joined = char
                    local ahead = self:peek(1)
                    self.Pos = self.Pos + 1
                    if OPCHARS[ahead] then
                        joined = joined .. ahead
                        if joined == "//" then
                            local comment = ""
                            local s = self.Pos
                            repeat 
                                comment = comment .. self:peek(1)
                                self.Pos = self.Pos + 1
                            until self:peek(1) == "\n"
                            table.insert(tok, self:token('Comment', comment, s,
                        self.Pos))
                        elseif joined == "/*" then
                            local comment = ""
                            local s = self.Pos
                            repeat 
                                comment = comment .. self:peek(1)
                                self.Pos = self.Pos + 1
                            until self:peek(1) == "*" and self:peek(2) == "/"
                            self.Pos = self.Pos + 2
                            table.insert(tok, self:token('Comment', comment, s,
                        self.Pos-2))
                        else
                            table.insert(tok, self:token('Symbol', joined, self.Pos,
                        self.Pos))
                        end
                        
                    else
                        table.insert(tok, self:token('Symbol', char, self.Pos,
                            self.Pos))
                        self.Pos = self.Pos - 1
                    end
                else
                    table.insert(tok,
                        self:token('Symbol', char, self.Pos, self.Pos))
                end
            elseif char == "\"" or char == '\'' then
                table.insert(tok, self:string(char))
            end
            self.Pos = self.Pos + 1
        end

        self.Tokens = tok
        return tok
    end
}

local BinaryPriority = {
    ['+'] = { 6, 6 },
    ['-'] = { 6, 6 },
    ['*'] = { 7, 7 },
    ['/'] = { 7, 7 },
    ['%'] = { 7, 7 },
    ['^'] = { 10, 9 },
    ['..'] = { 5, 4 },
    ['=='] = { 3, 3 },
    ['!='] = { 3, 3 },
    ['>'] = { 3, 3 },
    ['<'] = { 3, 3 },
    ['>='] = { 3, 3 },
    ['<='] = { 3, 3 },
    ['&&'] = { 2, 2 },
    ['||'] = { 1, 1 }
};

local BinopSet = lookupify {
    '+', '-', '*', '/', '%', '^', '#', '..', '.', ':', '>', '<', '<=', '>=',
    '!=', '==', '&&', '||'
}

local logger = require('lib.logger')

local parselog = logger.new('PARSE')

local function parse(str)

    local l = lexer.new(str)
    l:collect()

    local index = 1
    while index < #l.Tokens do
        local token = l.Tokens[index]
        if token.Type == "Comment" then
            print("COMMENT", table.remove(l.Tokens, index).Data)
        else
            index = index + 1
        end
    end

    --file.write('test/tokens.lua',string.format('local tokens = %s',serpent.line(l.Tokens)))

    local block, expr
    local Pos = 1

    local function consumeToken()
        local idx = Pos
        Pos = Pos + 1
        return l.Tokens[idx]
    end

    local function peek(n)
        n = n or 0
        local idx = Pos + n
        return l.Tokens[idx]
    end

    local function blockFollow()
        local tk = peek()
        return tk == nil or tk.Type == 'Eof' or tk.Data == '}'
    end

    local function fmtErr(msg, tk, ...)
        local posStart, posEnd = tk.Start, tk.End
        local line = tk.Line or 1
        local m = string.format(msg, ...)
        error(string.format('%s [Line %d :: %d:%d]', m, line, posStart, posEnd))
    end

    local function expect(Type, data)
        local tk = consumeToken()
        if data then
            if tk.Type ~= Type and tk.Data ~= data then
                fmtErr('Unexpected `%s` `%s` (expected `%s`)', tk, tk.Type,
                    tk.Data, data)
            end
        else
            if tk.Type ~= Type then
                fmtErr('Unexpected `%s` `%s` (expected `%s`)', tk, tk.Type,
                    tk.Data, Type)
            end
        end
        return tk
    end

    local function createNode(Type)
        parselog:drop(string.format("Created node %s", Type))
        return { Type = Type }
    end

    local function isBinop() return BinopSet[peek().Value] or false end
    local function isUnop() return (UNOPS[peek().Value] and peek().Type == "Symbol") or false end

    local function getTbValues()
        local val
        local vals = {}
        while consumeToken().Data ~= '}' do vals[#vals + 1] = expr() end
        return vals
    end

    local function prefixexpr()
        local tk = peek()
        local node
        if tk.Data == '(' then
            local opar = consumeToken()
            local inner = expr()
            local clar = expect('Symbol', ')')
            node = createNode('ParanExpr')
            node.Expression = inner
            node.OpenParan = opar
            node.CloseParan = clar
            node.GetFirst = function(self) return self.OpenParan end
            node.GetLast = function(self) return self.CloseParan end
        elseif tk.Type == 'String' then
            node = createNode('StringLit')
            local tok = consumeToken()
            node.Token = tok
            node.Value = tok.Value
        elseif tk.Type == 'Word' then
            node = createNode('Ident')
            node.Name = consumeToken().Data
        elseif tk.Data == '{' then
            node = createNode('ArrayExpr')
            local inside = getTbValues()
            local vals = createNode('Inside')
            vals.Values = inside
            node.Inside = vals
        end
        return node
    end

    local function blockbody(term)
        local body = block()
        local after = peek()
        --print(term,after.Data)
        if after.Data == term then
            consumeToken()
            return body, after
        end
    end

    local function arguments()
        local tk = peek()
        if tk.Data == '(' then
            local args = {}
            local opar = consumeToken()
            while peek().Data ~= ')' do
                local arg = expr()
                if peek().Data ~= ')' then expect('Symbol', ',') end
                args[#args + 1] = arg
            end
            local clpr = expect('Symbol', ')')
            local node = createNode('Arguments')
            node.ArgList = args
            node.OpenParan = opar
            node.CloseParan = clpr
            node.GetFirst = function(self) return self.OpenParan end
            node.GetLast = function(self) return self.CloseParan end
            return node
        end
    end

    local function primaryexpr()
        local base = prefixexpr()
        while true do
            local tk = peek()
            if peek(-1) and peek(-1).Data == ')' then return base end
            if tk.Data == '.' then
                local dot = consumeToken()
                local name = expect('Word')
                local node = createNode("FieldExpr")
                node.Field = name
                node.Dot = dot
                node.Base = base
                base = node
            elseif tk.Data == '[' then
                local ob = consumeToken()
                local idx = expr()
                local cb = expect('Symbol', ']')
                local node = createNode('IndexExpr')
                node.OpenBracket = ob
                node.CloseBracket = cb
                node.Value = idx
                node.Base = base
                base = node
            elseif tk.Data == '(' then
                local node = createNode('CallExpr')
                node.Base = base
                node.Arguments = arguments()
                base = node
            elseif tk.Type == 'Keyword' and
                (tk.Data == 'true' or tk.Data == 'false') then
                local node = createNode('BoolExpr')
                node.Value = tk.Data == 'true' and 1 or 0
                consumeToken()
                return node
            else
                return base
            end
        end
    end

    local function simpleexpr()
        local tk = peek()
        local node
        if tk.Type == 'Number' then
            node = createNode("NumberLit")
            node.Token = consumeToken()
            node.Value = node.Token.Value
        elseif tk.Type == 'String' then
            return primaryexpr()
        else
            return primaryexpr()
        end
        if node then
            node.GetFirst = function(self) return self.Token end
            node.GetLast = function(self) return self.Token end
        end
        return node
    end

    local function subexpr(limit)
        local node
        if isUnop() then
            local opTk = consumeToken()
            local ex = simpleexpr()
            node = createNode('UnopExpr')
            node.OpTk = opTk
            node.Op = opTk.Value
            node.Rhs = ex
            function node:GetFirst() return self.OpTk end

            function node:GetLast() return self.Rhs:GetLast() end
        else
            node = simpleexpr()
        end

        while isBinop() and BinaryPriority[peek().Value][1] > limit do
            local op = consumeToken()
            local rhs = subexpr(BinaryPriority[op.Value][2])
            assert(rhs, 'no rhs')
            node = {
                Lhs = node,
                Rhs = rhs,
                Op = op.Value,
                GetFirst = function(self)
                    return self.Lhs:GetFirst()
                end,
                GetLast = function(self)
                    return self.Rhs:GetFirst()
                end,
                Type = 'BinaryExpr'
            }
        end
        return node
    end

    local function Arglist()
        local arglist = createNode("ArgList")

        local args = {}
        local function read()
            local isPointer, ptrTok = peek().Type == 'Symbol' and peek().Data == '*',
                (peek().Type == 'Symbol' and peek().Data == '*') and consumeToken() or nil
            local arg = consumeToken()

            if arg.Data == ')' then
                Pos = Pos - 1
                return
            else
                local node = createNode("Argument")
                node.Data = arg
                node.Name = arg.Value
                node.IsPointer = isPointer
                node.PointerToken = ptrTok
                args[#args + 1] = node
            end
        end

        read()
        while peek().Data == ',' do
            consumeToken()
            read()
        end

        arglist.Args = args

        return arglist
    end

    local function get_proc_data()

        local data = {
            name = nil,
            event = nil,
            no_refresh = true
        }

        if peek().Type == "Symbol" then
            expect('Symbol', '@')
            local eventName = expect("Word")
            local args = {}
            if peek().Type == "Symbol" and peek().Data == "<" then
                while consumeToken().Data ~= '>' do args[#args + 1] = expect("Word").Data end
                print(serpent.block(args))
            end
            data.event = {eventName.Data, unpack(args)}
        else
            local name = expect('Word')

            if name.Data == "refresh" then
                data.no_refresh = false
                name = expect("Word")
            end
            data.name = name.Data
        end
        return data
    end

    local function procedure()
        consumeToken()
        local node = createNode("Procedure")
        
        local proc_data = get_proc_data()
        

        
        local open = expect('Symbol', '(')
        local arglist = Arglist()
        local close = expect('Symbol', ')')
        expect('Symbol', '{')
        local body = blockbody("}")

        -- print(arglist)

        node.Name = proc_data.name
        node.ArgList = arglist
        node.NoRefresh = proc_data.no_refresh
        node.Event = proc_data.event
        node.Opening = open
        node.Closing = close
        node.Body = body
        -- node.ReturnType = p_type.Data

        return node
    end

    expr = function() return subexpr(0) end

    local function exprstat()
        local ex = primaryexpr()

        if ex.Type == 'CallExpr' then
            local node = createNode('CallStat')
            node.Expression = ex
            node.GetFirst = function(self)
                return self.Expression:GetFirst()
            end
            node.GetLast = function(self)
                return self.Expression:GetLast()
            end
            return node
        else
            local lhs = { ex }
            while peek().Data == ',' do
                local lh = primaryexpr()
                if lh.Type == 'CallExpr' then
                    fmtErr("Invalid left-hand")
                end
                table.insert(lhs, lh)
            end
            local eq = expect('Symbol', '=')
            local rhs = { expr() }
            while peek().Data == ',' do table.insert(rhs, expr()) end
            local node = createNode("AssignStat")
            node.Rhs = rhs
            node.Lhs = lhs
            node.Equals = eq
            node.GetFirst = function(self)
                return self.Lhs[1]:GetFirst()
            end
            node.GetLast = function(self)
                return self.Rhs[#self.Rhs]:GetLast()
            end
            return node
        end
    end

    local function varlist(assignToken)
        local list = {}

        do
            local star = peek().Type == 'Symbol' and peek().Data == '*'

            if star then
                consumeToken()
            end

            if peek().Type == 'Word' then
                local node = createNode("Var")
                local tok = consumeToken()
                node.Name = tok.Value
                node.IsPointer = star ~= nil and true
                node.PointerToken = star
                node.AssignToken = assignToken

                table.insert(list, node)
            end
        end

        while peek().Data == ',' do
            consumeToken()
            local star = peek().Type == 'Symbol' and peek().Data == '*'

            if star then
                consumeToken()
            end

            local id = expect('Word')
            local node = createNode('Var')
            node.Name = id.Value
            node.IsPointer = star ~= nil and true
            node.PointerToken = star

            table.insert(list, node)
        end
        local node = createNode("VarList")
        node.List = list
        return node
    end

    local function exprlist()
        local list = {}
        table.insert(list, expr())
        while peek().Data == ',' do
            consumeToken()
            table.insert(list, expr())
        end
        local node = createNode("ExprList")
        node.List = list
        return node
    end

    local function varinit()
        local kw = consumeToken()
        local node = createNode('VarStat')

        local vl = varlist(kw)
        local el
        local eq

        if peek().Data == '=' then
            eq = consumeToken()
            el = exprlist()
        end

        node.Vars = vl
        node.Init = el
        node.AssignToken = kw

        node.Equals = eq

        return node
    end

    local function returnstat()
        local rk = consumeToken()
        local list
        if blockFollow() then
            list = {}
        else
            list = exprlist()
        end
        local node = createNode('RetStat')
        node.List = list
        return node, #list
    end

    local function ifstat()
        local ifkw = consumeToken()
        local condition = expr()

        local Then = expect('Symbol', '{')
        local body = blockbody("}")

        local node = createNode("IfStat")

        local elses = {}

        while peek().Data == 'else' do
            local elsekw = consumeToken()
            local eif, open
            if peek().Data == 'if' then
                consumeToken()
                eif = expr()
            end
            open = expect('Symbol', '{')
            local ebody = blockbody('}')
            table.insert(elses, {
                Condition = eif,
                Body = ebody,
                Token = elsekw,
                TokenThen = open,
                ElseIf = eif ~= nil
            })
        end

        node.Condition = condition
        node.Body = body
        node.Elses = elses
        node.TokenThen = Then
        node.TokenIf = ifkw
        node.TokenEnd = peek(-1)

        -- Pos=Pos+1

        return node
    end

    local function forstat()
        local node = createNode("ForStat")

        local forkw = consumeToken()
        local name = prefixexpr()
        local eq = expect('Symbol', '=')

        local list = exprlist()
        list = list.List

        local start, limit, step = list[1], list[2], list[3]

        assert(start, 'For loop (no start)')
        assert(limit, 'For loop (no limit)')
        assert(step, 'For loop (no step)')

        local opar = expect('Symbol', '{')

        local body = blockbody('}')
        Pos = Pos - 1
        local clpr = expect('Symbol', '}')

        node.Start = start
        node.Limit = limit
        node.Step = step

        node.Body = body
        node.TokenFor = forkw
        node.Name = name
        node.Open = opar
        node.Close = clpr
        return node
    end

    local function whilestat()
        local node = createNode("WhileStat")

        local condition
        local wkw = consumeToken()

        condition = expr()
        expect('Symbol', '{')
        local body = blockbody('}')

        node.Condition = condition
        node.Body = body

        return node
    end

    local function preprocessor()
        local ptok = consumeToken()
        local pline = ptok.Line
        local pdata = {}
        local prep = createNode('PrepStat')
        prep.Base = consumeToken()

        while peek() and peek().Line == pline and peek().Type ~= 'Eof' do
            if peek().Type ~= 'Eof' then
                pdata[#pdata + 1] = consumeToken().Value
            end
        end
        prep.Data = pdata
        return prep
    end

    local function asmstat()
        local node = createNode("AsmStat")
        local entry = consumeToken()
        local isInline, inlineToken = peek().Type == 'Keyword' and peek().Data == 'inline',
            (peek().Type == 'Keyword' and peek().Data == 'inline') and consumeToken() or 0                                                                                 -- absolutely cursed oneliner

        expect("Symbol", "{")

        node.Token = entry
        node.IsInline = isInline
        node.InlineToken = inlineToken ~= 0 and inlineToken or nil

        local data = {}
        local lastline = peek()

        node.Lines = {}

        local lreg = {
            i = 0,
            j = 0,
            k = 0,
            x = 0,
            y = 0,
            z = 0,
            r0 = 0,
            r1 = 0,
            r2 = 0,
            r3 = 0,
            r4 = 0,
            r5 = 0,
            r6 = 0,
            r7 = 0,
            r8 = 0,
            r9 = 0,
            r10 = 0
        }

        local opcodes = require("instructions")

        while peek().Data ~= '}' do
            local tok = consumeToken()
            local tokData = tok.Data
            local tokLine = tok.Line

            if tokData == '&' then
                local t = expect('Word')
                tokData = tokData .. t.Data
            end

            if opcodes[tokData] == nil and lreg[tokData] == nil and tokData ~= "&" and tokData:sub(1, 1) ~= '&' then
                if tonumber(tokData) == nil then
                    tokData = "\"" .. tokData .. "\""
                end
            end
            if tokLine ~= lastline then
                table.insert(node.Lines, table.concat(data, ' '))
                data = {}
            end

            table.insert(data, tokData)
            lastline = tokLine
        end

        consumeToken() -- ending brackets

        table.insert(node.Lines, table.concat(data, ' '))
        --Pos=Pos+1
        if peek().Type == 'Keyword' and peek().Data == 'as' then
            expect("Keyword", "as")
            local name = consumeToken()
            node.Saved = true
            node.Name = name
        end


        return node
    end

    local scratch_block_body

    local function scratch_block()
        local call = primaryexpr()
        local target = call and call.Type == "CallExpr" and call.Base or nil
        if target == nil or target.Type ~= "StringLit" then
            fmtErr("Scratch block must be a quoted opcode or command followed by arguments", peek())
        end

        local node = createNode("ScratchBlock")
        node.Call = call
        node.Body = nil
        node.ElseBody = nil
        node.Token = target.Token
        node.Line = target.Token.Line

        if peek().Data == "{" then
            consumeToken()
            node.Body = scratch_block_body()
        end

        if peek().Data == "else" then
            local else_token = consumeToken()
            if peek().Data ~= "{" then
                fmtErr("Scratch else must be followed by a block body", peek())
            end
            consumeToken()
            node.ElseToken = else_token
            node.ElseBody = scratch_block_body()
        end

        return node
    end

    scratch_block_body = function()
        local blocks = {}

        while true do
            local tk = peek()
            if tk == nil or tk.Type == "Eof" then
                fmtErr("Unterminated scratch block body", tk)
            end
            if tk.Data == "}" then
                consumeToken()
                return blocks
            end

            if tk.Type ~= "String" then
                fmtErr("Expected a quoted Scratch opcode or command", tk)
            end

            blocks[#blocks + 1] = scratch_block()
        end
    end

    local function scratchstat()
        local token = consumeToken()
        if peek().Data ~= "{" then
            fmtErr("Expected `{` after `scratch`", peek())
        end
        local opening = consumeToken()

        local node = createNode("ScratchStat")
        node.Token = token
        node.Opening = opening
        node.Blocks = scratch_block_body()
        return node
    end

    local function statement()
        local last = false
        local stat, numReturns
        local tk = peek()
        if tk.Data == '(' or tk.Data == ')' or tk.Type == 'Number' then
            stat = expr()
        elseif tk.Type == 'Keyword' and tk.Data == 'scratch' then
            stat = scratchstat()
        elseif tk.Type == 'Keyword' and tk.Data == 'asm' then
            stat = asmstat()
        elseif tk.Type == 'Keyword' and tk.Data == 'proc' then
            stat = procedure()
        elseif tk.Type == 'Keyword' and VAR_KEYWORDS[tk.Data] then
            stat = varinit()
        elseif tk.Type == 'Keyword' and tk.Data == 'return' then
            stat = returnstat()
            numReturns = 0
            for i, v in pairs(stat.List.List) do
                numReturns = numReturns + 1
            end
        elseif tk.Type == 'Keyword' and tk.Data == 'if' then
            stat = ifstat()
        elseif tk.Type == 'Keyword' and tk.Data == 'for' then
            stat = forstat()
        elseif tk.Type == 'Keyword' and tk.Data == 'while' then
            stat = whilestat()
        elseif tk.Data == '#' then
            stat = preprocessor()
        else
            stat = exprstat()
        end

        stat.Line = tk.Line

        if stat then
            parselog:drop(string.format("Generated " .. stat.Type))
        else
            fmtErr('Unexpected token: `%s`', tk, tk.Value)
        end

        return stat, last, numReturns
    end

    local level = 0

    block = function()
        level = level + 1
        local statements = {}
        local numReturns
        local node = createNode("StatList")
        node.Statements = statements
        node.Returns = 0

        local isLast = false

        parselog:drop(string.format('Block level %d', level))
        parselog:drop("------------------------")

        while not isLast and not blockFollow() do
            local stat
            stat, isLast, numReturns = statement()
            if numReturns then node.Returns = numReturns end
            table.insert(statements, stat)
        end

        parselog:drop(string.format('Exited level %d', level))
        parselog:drop("------------------------")

        level = level - 1

        return node
    end

    local function collect_locals(level)
        level = (level or 1) + 1  -- shift to caller
        local vars = {}
        local i = 1

        while true do
            local name, value = debug.getlocal(level, i)
            if not name then break end
            vars[name] = value
            i = i + 1
        end

        return vars
    end

    return #str > 0 and block() or nil, l, collect_locals()
end

local function VarInfo(ast)
    local function createScope(parent)
        local scope = {}
        local vars = {}
        local procs = {}
        local sub_idx = 0

        function scope:Var(varStat)
            local v, i = self:Get(varStat.Name)
            if v then return v, i end
            local index = #vars + 1
            local var = {
                Name = varStat.Name,
                AssignToken = varStat.AssignToken,
                Index = index,
                References = 0,
                Type = 'local',
                RefScopes = {},
                URefScopes = 0
            }
            var.Reference = function(self, refScope)
                self.References = self.References + 1
                if self.RefScopes[refScope] == nil then
                    self.RefScopes[refScope] = refScope
                    self.URefScopes = self.URefScopes + 1
                end
            end
            return var, index
        end

        function scope:Arg(name)
            for i, v in pairs(self.Vars) do
                if v.Name == name and v.Type == 'argument' then
                    return v, i
                end
            end
            local index = #vars + 1
            self.Params = self.Params + 1
            local var = {
                Name = name,
                Index = index,
                References = 0,
                Type = 'argument',
                RefScopes = {},
                URefScopes = 0
            }
            var.Reference = function(self, refScope)
                self.References = self.References + 1
                self.RefScopes[refScope] = refScope
                if self.RefScopes[refScope] == nil then
                    self.RefScopes[refScope] = refScope
                    self.URefScopes = self.URefScopes + 1
                end
            end
            return var, index
        end

        function scope:GetLocal(name)
            for i, v in pairs(self.Vars) do
                if v.Name == name then return v, i end
            end
        end

        function scope:Get(name)
            for i, v in pairs(self.Vars) do
                if v.Name == name then return v, i end
            end
            return parent and parent:Get(name)
        end

        function scope:Proc(name, params, returns)
            for i, v in pairs(self.Procedures) do
                if v.Name == name and v.NumParam == #params then
                    return v, i
                end
            end
            local index = #self.Procedures + 1
            local proc = {
                Name = name,
                Params = params,
                NumParam = #params,
                Returns = returns,
                SubIndex = sub_idx + 1,
                References = 0,
                RefScopes = {},
                URefScopes = 0
            }

            proc.Reference = function(self, refScope)
                self.References = self.References + 1
                self.RefScopes[refScope] = refScope
                if self.RefScopes[refScope] == nil then
                    self.RefScopes[refScope] = refScope
                    self.URefScopes = self.URefScopes + 1
                end
            end

            sub_idx = sub_idx + 1
            return proc, index
        end

        function scope:GetReturns(name)
            for i, v in pairs(self.Procedures) do
                if v.Name == name then return v.Returns end
            end
        end

        function scope:Set(name)
            self:Var(name)
        end

        scope.Vars = vars
        scope.Procedures = procs
        scope.Params = 0
        scope.Parent = parent

        return scope
    end

    local function doStat(tree, init, parentScope)
        local scope = createScope(parentScope)
        tree.Scope = scope
        scope.VarLookup = {}
        scope.ProcLookup = {}

        if init then
            for idx, arg in pairs(init.Args) do
                local var = scope:Arg(arg.Name)
                -- print(serpent.block(arg))
                var.is_pointer = arg.IsPointer
                var.v_type = arg.DataType
                -- print(serpent.block(var))
                scope.Vars[var.Index] = var
            end
        end

        local function findRefs(stat)
            if stat.Type == 'StatList' then
                for i, v in pairs(stat.Statements) do findRefs(v) end
            elseif stat.Type == 'VarStat' then
                for i, v in pairs(stat.Vars.List) do
                    local var = scope:Get(v.Name)
                    var.is_pointer = var.IsPointer
                    assert(var, "No variable " .. v.Name)
                    var:Reference(scope)
                end
            elseif stat.Type == 'CallStat' then
                local expr = stat.Expression
                local base = expr.Base.Name

                if scope.ProcLookup[base] then
                    local function GetProc()
                        for i, v in pairs(scope.Procedures) do
                            if v.Name == base then return v end
                        end
                    end

                    GetProc():Reference(scope)
                end --]]

                for i, v in pairs(expr.Arguments.ArgList) do
                    if v.Type == 'Ident' then
                        local var = scope:Get(v.Name)
                        if var == nil then
                            parselog:drop("[WARN] Not in scope " .. v.Name)
                        else
                            var:Reference(scope)
                        end
                    end
                end
            elseif stat.Type == 'AssignStat' then
                for i, v in pairs(stat.Lhs) do
                    if v.Type == 'Ident' then
                        local var = scope:Get(v.Name)
                        assert(var, "Not in scope " .. v.Name)
                        var:Reference(scope)
                    end
                end
            end
        end

        for i, branch in pairs(tree.Statements) do
            if branch.Type == 'Procedure' then
                local name = branch.Name
                local body = branch.Body
                local params = branch.ArgList
                if body then
                    local p, k = scope:Proc(name, params, body.Returns)
                    scope.Procedures[k] = p
                    if name ~= nil then
                        scope.ProcLookup[name] = true
                    end
                    doStat(body, params, scope)
                end
            elseif branch.Type == 'CallStat' then
                local expr = branch.Expression
                local base = expr.Base.Name

                if scope.ProcLookup[base] then
                    local function GetProc()
                        for i, v in pairs(scope.Procedures) do
                            if v.Name == base then return v end
                        end
                    end

                    GetProc():Reference(scope)
                end
            elseif branch.Type == 'VarStat' then
                for idx, var in pairs(branch.Vars.List) do
                    local v, k = scope:Var(var)
                    scope.Vars[k] = v
                    scope.VarLookup[var.Name] = true
                end
            elseif branch.Type == 'AssignStat' then
                local lhs = branch.Lhs
                for idx, var in pairs(lhs) do
                    local name = var.Name
                    local v = scope:Var(var)
                end
            elseif branch.Type == 'RetStat' then
                local list = branch.List.List
                for idx, val in pairs(list) do
                    local Type = val.Type
                    if Type == 'Ident' then
                        local var = scope:Get(val.Name)
                        assert(var, "No scope: " .. var.Name)
                        var:Reference(scope)
                    end
                end
            end
        end

        findRefs(tree)

        return tree
    end

    return doStat(ast)
end

return {
    parse = parse,
    varinfo = VarInfo,
    lex = function(str)
        local l = lexer.new(str)
        return l:collect()
    end,
    unops = UNOPS,
    conds = CONDS,
    BinopSet = BinopSet,
    operators = OPERATORS,
    toggle_logger = function(x)
        parselog.active = x or false
    end
}
