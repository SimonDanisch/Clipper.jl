function to_intpoints(x::Vector{NTuple{2, T}}) where T
    mini, maxi = extrema(x)
    width = T(0.5) * (maxi - mini)
    imaxi = typemax(Cint)
    map(x) do elem
        n1to1 = ((elem .- mini) ./ width) .- T(1)
        round.(Cint, n1to1 .* imaxi)
    end
end
