using MLStyle
using DataStructures

@data LExp begin
    LLet(Bool, Vector{Tuple{String, LExp}}, LExp)
    LFun(Vector{String}, LExp)
    LMatch(LExp, Vector{Tuple{LExp, LExp}})       # *
    LIf(LExp, LExp, LExp)
    LConst{T} :: T => LExp
    LVar(String)
    LBlock(Vector{LExp})
    LAttr(LExp, String)                           # *
    LCall(LExp, Vector{LExp})
    LList(Vector{LExp})
    LBin(Vector{Union{LExp, Token}})              # *
    LInfix(String, Int, Bool)
    LDefine(String, LExp)
    LModule(String, Vector{String}, Vector{LExp}) # *
    LCustom(LExp, Vector{Tuple{String, LExp}})
    LLoc(Any, LExp)
    LStaged(Any)
end

to_lexp(s :: RStr) = LLoc(s.loc, LConst(s.value))
to_lexp(s :: RLet) = LLoc(s.loc, LLet(s.rec, [(a, to_lexp(b)) for (a, b) in s.binds], to_lexp(s.body)))
to_lexp(s :: RFun) = LLoc(s.loc, LFun(s.args), to_lexp(s.body))
to_lexp(s :: RMatch) = LLoc(s.loc, LMatch(to_lexp(s.sc), [(to_lexp(a), to_lexp(b)) for (a, b) in s.cases]))
to_lexp(s :: RIf) = LIf(s.loc, to_lexp(s.cond), to_lexp(s.br1), to_lexp(s.br2))
to_lexp(s :: RNum) =
    let app = s.neg ? (x -> -x) : (x -> x)
        LConst(app(s.int === nothing ? parse(Float64, s.float) : parse(Int64, s.int)))
    end
to_lexp(s::RBoolean) = LConst(s.value.str == "true" ? true : false)
to_lexp(s:: RNil) = LConst(nothing)
to_lexp(s:: RVar) = LVar(s.value)
to_lexp(s:: RBlock) = LLoc(s.loc, LBlock([to_lexp(each) for each in s.stmts]))
to_lexp(s:: RAttr) = s.attr === nothing ? to_lexp(s.value) : LLoc(s.loc, LAttr(to_lexp(s.value), s.attr))
to_lexp(s:: RCall) = isempty(s.args) ? to_lexp(s.fn) : LCall(to_lexp(s.fn), map(to_lexp, s.args))
to_lexp(s:: RList) = LLoc(s.loc, LList([to_lexp(e) for e in s.elts]))
to_lexp(s:: RTop) = isempty(s.tl) ? to_lexp(s.hd) : let tl = s.tl
        binseq = Union{LExp, Token}[]
        push!(binseq, to_lexp(s.hd))
        for (op, e) in tl
            push!(binseq, op.name)
            push!(binseq, to_lexp(e))
        end
        LBin(binseq)
    end

function _pack(a::RCustom)
    s = []
    while a isa Custom
        v = to_lexp(a.value)
        if a.kw === nothing
            push!(s, ("", v))
        else
            push!(s, (a.kw, v))
        end
        a = a.next
    end
    s
end
_pack(::Nothing) = []

to_lexp(s:: RExp) = !s.do_custom ? to_lexp(s.top) : LCustom(to_lexp(s.top), _pack(s.custom))
to_lexp(s:: RDefine) = LDefine(s.name, to_lexp(s.value))
to_lexp(s:: RInfix) = LLoc(s.loc, LInfix(s.name, parse(Int, s.prec), s.is_right))
to_lexp(s:: RModule) = LLoc(s.loc, LModule(s.name, s.params, [to_lexp(e) for e in s.stmts]))


