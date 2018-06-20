function to_intpoints(x::AbstractVector{X}) where X <: AbstractVector
    result = Vector{Vector{IntPoint}}(length(x)) # do not use broadcast/similar, to make sure we get a Vector
    @inbounds for (i, elem) in enumerate(x)
        result[i] = to_intpoints(elem)
    end
    result
end
function to_intpoints(x::AbstractVector{T}) where T
    if length(T) != 2
        error("`length(T)` needs to be 2`")
    end
    if !isbits(T)
        error("`T` needs to be isbits (not cointain pointers, immutable. E.g. Tuple{Float64, Float64})")
    end
    to_intpoints(reinterpret(NTuple{2, T}, x))
end

function to_intpoints(x::AbstractVector{X}) where X <: NTuple{2, T} where T <: Number
    mini, maxi = extrema(x)
    width = T(0.5) * (maxi - mini)
    imaxi = typemax(Cint)
    result = Vector{IntPoint}(length(x))
    @inbounds for (i, elem) in enumerate(x)
        n1to1 = ((elem .- mini) ./ width) .- T(1)
        int_tup = round.(Cint, n1to1 .* imaxi)
        result[i] = IntPoint(int_tup[1], int_tup[2]))
    end
    result
end
