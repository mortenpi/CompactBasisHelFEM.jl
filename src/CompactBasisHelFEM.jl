module CompactBasisHelFEM
using ContinuumArrays: SimplifyStyle
using CompactBases: CompactBases, Basis, @materialize, LazyArrays, ContinuumArrays,
    QuasiAdjoint, QuasiDiagonal, Derivative, BroadcastQuasiArray
import CompactBases: locs
using HelFEM: HelFEM

# This comes from EllipsisNotation via CompactBases, but can't be imported with using
const .. = CompactBases.:(..)

struct HelFEMBasis <: Basis{Float64}
    b :: HelFEM.FEMBasis
end

function Base.axes(b::HelFEMBasis)
    rmin, rmax = first(HelFEM.boundaries(b.b)), last(HelFEM.boundaries(b.b))
    (CompactBases.Inclusion(rmin..rmax), Base.OneTo(length(b.b)))
end

function Base.getindex(b::HelFEMBasis, r::Number, i)
    r ∈ axes(b,1) && i ∈ axes(b,2) || throw(BoundsError(b, [r,i]))
    b.b([r])[i]
end

function Base.getindex(b::HelFEMBasis, r::Vector, i)
    all(∈(axes(b,1)), r) && (i isa Colon || all(∈(axes(b,2)),i)) || throw(BoundsError(b, [r,i]))
    b.b(r)[:,i]
end

Base.getindex(b::HelFEMBasis, r::AbstractVector, i) = b[collect(r), i]

# Overlap matrix
@materialize function *(Ac::QuasiAdjoint{<:Any,<:HelFEMBasis}, B::HelFEMBasis)
    SimplifyStyle
    T -> begin
        A = parent(Ac)
        @assert A == B
        Matrix{T}(undef, length(A.b), length(B.b))
    end
    dest::Matrix{T} -> begin
        A = parent(Ac)
        dest .= HelFEM.radial_integral(A.b, r -> 1.0)
    end
end

# Potential
@materialize function *(Ac::QuasiAdjoint{<:Any,<:HelFEMBasis}, D::QuasiDiagonal, B::HelFEMBasis)
    SimplifyStyle
    T -> begin
        A = parent(Ac)
        @assert A == B
        Matrix{T}(undef, length(A.b), length(B.b))
    end
    dest::Matrix{T} -> begin
        A = parent(Ac)
        dest .= HelFEM.radial_integral(A.b, r -> first(getindex.(Ref(D.diag), [r])))
    end
end


@materialize function *(Ac::QuasiAdjoint{<:Any,<:HelFEMBasis}, D::Derivative, B::HelFEMBasis)
    SimplifyStyle
    T -> begin
        A = parent(Ac)
        @assert A == B
        Matrix{T}(undef, length(A.b), length(B.b))
    end
    dest::Matrix{T} -> begin
        A = parent(Ac)
        dest .= HelFEM.radial_integral(A.b, r -> 1.0, rderivative = true)
    end
end

@materialize function *(Ac::QuasiAdjoint{<:Any,<:HelFEMBasis}, Dc::QuasiAdjoint{<:Any,<:Derivative}, D::Derivative, B::HelFEMBasis)
    SimplifyStyle
    T -> begin
        A = parent(Ac)
        @assert A == B
        Matrix{T}(undef, length(A.b), length(B.b))
    end
    dest::Matrix{T} -> begin
        A = parent(Ac)
        dest .= HelFEM.radial_integral(A.b, r -> 1.0, lderivative = true, rderivative = true)
    end
end

function Sinvh(A::HelFEMBasis)
    S = HelFEM.radial_integral(A.b, r -> 1.0)
    return real(inv(sqrt(Hermitian(S))))
end

# Interpolating functions over HelFEMBasis
locs(B::HelFEMBasis) = HelFEM.controlpoints(B.b)

function Base.:(\ )(B::HelFEMBasis, f::BroadcastQuasiArray)
    @assert B.b.pb.primbas == 4 # only works for LIPs at the moment
    axes(f,1) == axes(B,1) || throw(DimensionMismatch("Function on $(axes(f,1).domain) cannot be interpolated over basis on $(axes(B,1).domain)"))
    cs = locs(B)
    collect(f[cs[2:end-1]])
end

# TODO: Is this sensible?
CompactBases.assert_compatible_bases(A::HelFEMBasis, B::HelFEMBasis) = A == B
Base.:(==)(A::HelFEMBasis, B::HelFEMBasis) = A.b == B.b

end
