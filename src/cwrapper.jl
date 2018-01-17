if isfile("../deps/deps.jl")
    include("../deps/deps.jl")
    check_deps()
else
    error("Clipper.jl not correctly build. Please run Pkg.build(\"Clipper\") and try again!")
end

@enum PolyType PolyTypeSubject=0 PolyTypeClip=1

@enum ClipType ClipTypeIntersection=0 ClipTypeUnion=1 ClipTypeDifference=2 ClipTypeXor=3

@enum PolyFillType PolyFillTypeEvenOdd=0 PolyFillTypeNonZero=1 PolyFillTypePositive=2 PolyFillTypeNegative=3

@enum JoinType JoinTypeSquare=0 JoinTypeRound=1 JoinTypeMiter=2

@enum EndType EndTypeClosedPolygon=0 EndTypeClosedLine=1 EndTypeOpenSquare=2 EndTypeOpenRound=3 EndTypeOpenButt=4



struct IntPoint
    X::Int64
    Y::Int64
end
struct DoublePoint
    X::Cdouble
    Y::Cdouble
end

mutable struct PolyNode{T}
    contour::Vector{T}
    hole::Bool
    open::Bool
    children::Vector{PolyNode{T}}
    parent::PolyNode{T}
    PolyNode{T}(a,b,c) where {T} = new{T}(a,b,c)
    function PolyNode{T}(a,b,c,d) where T
        p = new{T}(a,b,c,d)
        p.parent = p
        return p
    end
    PolyNode{T}(a,b,c,d,e) where {T} = new{T}(a,b,c,d,e)
end

Base.convert(::Type{PolyNode{T}}, x::PolyNode{T}) where {T} = x
function Base.convert(::Type{PolyNode{S}}, x::PolyNode{T}) where {S,T}
    parent(x) !== x && error("must convert a top-level PolyNode (i.e. a PolyTree).")

    pn = PolyNode{S}(convert(Vector{S}, contour(x)), ishole(x), isopen(x))
    pn.children = [PolyNode(y,pn) for y in children(x)]
    pn.parent = pn
end
function PolyNode(x::PolyNode, parent::PolyNode{S}) where S
    pn = PolyNode{S}(contour(x), ishole(x), isopen(x))
    pn.children = [PolyNode(y,pn) for y in children(x)]
    pn.parent = parent
    pn
end

@inline ishole(x::PolyNode) = x.hole
@inline Base.isopen(x::PolyNode) = x.open
@inline contour(x::PolyNode) = x.contour
@inline children(x::PolyNode) = x.children
@inline Base.parent(x::PolyNode) = x.parent

function Base.show(io::IO, node::PolyNode)
    if parent(node) === node
        print(io, "Top-level PolyNode with $(length(children(node))) immediate children.")
    else
        if isopen(node)
            print(io, "Open ")
        else
            print(io, "Closed ")
        end
        print(io, "PolyNode ")
        ishole(node) && print(io, "(hole) ")
        println(io, "with contour:")
        show(io, contour(node))
        println(io, "")
        print(io, "...and $(length(children(node))) immediate children.")
    end
end

function Base.show(io::IO, point::IntPoint)
  print(io, "[$(point.X),$(point.Y)]")
end

function append!(outputArray::Ptr{Void}, polyIndex::Csize_t, point::IntPoint)
    ourArray = unsafe_pointer_to_objref(outputArray)::Vector{Vector{IntPoint}}

    while (polyIndex + 1) > length(ourArray)
        push!(ourArray, Vector{IntPoint}())
    end

    push!(ourArray[polyIndex + 1], point)
end

# private
function appendpn!(jl_node::Ptr{Void}, point::IntPoint)
    node = unsafe_pointer_to_objref(jl_node)::PolyNode{IntPoint}
    push!(contour(node), point)
end

# private
function newnode(outputTree::Ptr{Void}, ishole::Bool, isopen::Bool)
    tree = unsafe_pointer_to_objref(outputTree)::PolyNode{IntPoint}
    node = PolyNode{IntPoint}(IntPoint[], ishole, isopen, PolyNode{IntPoint}[], tree)
    push!(children(tree), node)
    pointer_from_objref(node)
end

#==============================================================#
# Static functions
#==============================================================#
function orientation(path::Vector{IntPoint})
    ccall((:orientation, clipper_lib), Cuchar, (Ptr{IntPoint}, Csize_t),
        path,
        length(path)) == 1 ? true : false
end

function area(path::Vector{IntPoint})
    ccall((:area, clipper_lib), Float64, (Ptr{IntPoint}, Csize_t),
        path,
        length(path))
end

function pointinpolygon(pt::IntPoint, path::Vector{IntPoint})
    ccall((:pointinpolygon, clipper_lib), Cint, (IntPoint, Ptr{IntPoint}, Csize_t),
        pt,
        path,
        length(path))
end

#==============================================================#
# Clipper object
#==============================================================#
mutable struct Clip
    clipper_ptr::Ptr{Void}

    function Clip()
        clipper = new(ccall((:get_clipper, clipper_lib), Ptr{Void}, ()))
        finalizer(clipper, c -> ccall((:delete_clipper, clipper_lib), Void, (Ptr{Void},), c.clipper_ptr))

        clipper
    end
end

function add_path!(c::Clip, path::Vector{IntPoint}, polyType::PolyType, closed::Bool)
    ccall((:add_path, clipper_lib), Cuchar, (Ptr{Void}, Ptr{IntPoint}, Csize_t, Int64, Cuchar),
          c.clipper_ptr,
          path,
          length(path),
          Int(polyType),
          closed) == 1 ? true : false
end

function add_paths!(c::Clip, paths::Vector{Vector{IntPoint}}, polyType::PolyType, closed::Bool)
    lengths = Vector{UInt64}()
    for path in paths
        push!(lengths, length(path))
    end

    ccall((:add_paths, clipper_lib), Cuchar, (Ptr{Void}, Ptr{Ptr{IntPoint}}, Ptr{Csize_t}, Csize_t, Int64, Cuchar),
          c.clipper_ptr,
          paths,
          lengths,
          length(paths),
          Int(polyType),
          closed) == 1 ? true : false
end

function execute(c::Clip, clipType::ClipType, subjFillType::PolyFillType, clipFillType::PolyFillType)
    polys = Vector{Vector{IntPoint}}()

    result = ccall((:execute, clipper_lib), Cuchar, (Ptr{Void}, Int64, Int64, Int64, Any, Ptr{Void}),
                    c.clipper_ptr,
                    Int(clipType),
                    Int(subjFillType),
                    Int(clipFillType),
                    polys,
                    cfunction(append!, Any, (Ptr{Void}, Csize_t, IntPoint)))

    return result == 1 ? true : false, polys
end

function execute_pt(c::Clip, clipType::ClipType, subjFillType::PolyFillType, clipFillType::PolyFillType)
    pt = PolyNode{IntPoint}(IntPoint[], false, false, PolyNode{IntPoint}[])

    result = ccall((:execute_pt, clipper_lib), Cuchar,
        (Ptr{Void}, Int64, Int64, Int64, Any, Ptr{Void}, Ptr{Void}),
        c.clipper_ptr,
        Int(clipType),
        Int(subjFillType),
        Int(clipFillType),
        pt,
        cfunction(newnode, Ptr{Void}, (Ptr{Void}, Bool, Bool)),
        cfunction(appendpn!, Any, (Ptr{Void}, IntPoint)))

    return result == 1 ? true : false, pt
end

function clear!(c::Clip)
    ccall((:clear, clipper_lib), Void, (Ptr{Void},), c.clipper_ptr)
end

mutable struct IntRect
    left::Int64
    top::Int64
    right::Int64
    bottom::Int64
end

function get_bounds(c::Clip)
    ccall((:get_bounds, clipper_lib), IntRect, (Ptr{Void}, ), c.clipper_ptr)
end

#==============================================================#
# ClipperOffset object
#==============================================================#
mutable struct ClipperOffset
    clipper_ptr::Ptr{Void}

    function ClipperOffset(miterLimit::Float64 = 2.0, roundPrecision::Float64 = 0.25)
        clipper = new(ccall((:get_clipper_offset, clipper_lib), Ptr{Void}, (Cdouble, Cdouble), miterLimit, roundPrecision))
        finalizer(clipper, c -> ccall((:delete_clipper_offset, clipper_lib), Void, (Ptr{Void},), c.clipper_ptr))

        clipper
    end
end

function add_path!(c::ClipperOffset, path::Vector{IntPoint}, joinType::JoinType, endType::EndType)
    ccall((:add_offset_path, clipper_lib), Void, (Ptr{Void}, Ptr{IntPoint}, Csize_t, Int64, Int64),
          c.clipper_ptr,
          path,
          length(path),
          Int(joinType),
          Int(endType))
end

function add_paths!(c::ClipperOffset, paths::Vector{Vector{IntPoint}}, joinType::JoinType, endType::EndType)
    lengths = Vector{UInt64}()
    for path in paths
        push!(lengths, length(path))
    end

    ccall((:add_offset_paths, clipper_lib), Void, (Ptr{Void}, Ptr{Ptr{IntPoint}}, Ptr{Csize_t}, Csize_t, Int64, Int64),
          c.clipper_ptr,
          paths,
          lengths,
          length(paths),
          Int(joinType),
          Int(endType))
end

function clear!(c::ClipperOffset)
    ccall((:clear_offset, clipper_lib), Void, (Ptr{Void},), c.clipper_ptr)
end

function execute(c::ClipperOffset, delta::Float64)
    polys = Vector{Vector{IntPoint}}()

    result = ccall((:execute_offset, clipper_lib), Void, (Ptr{Void}, Cdouble, Any, Ptr{Void}),
                    c.clipper_ptr,
                    delta,
                    polys,
                    cfunction(append!, Any, (Ptr{Void}, Csize_t, IntPoint)))

    return polys
end
