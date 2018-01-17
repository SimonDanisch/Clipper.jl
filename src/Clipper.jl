__precompile__()
module Clipper

include("cwrapper.jl")
include("conversion.jl")

export PolyType, PolyTypeSubject, PolyTypeClip,
       ClipType, ClipTypeIntersection, ClipTypeUnion, ClipTypeDifference, ClipTypeXor,
       PolyFillType, PolyFillTypeEvenOdd, PolyFillTypeNonZero, PolyFillTypePositive, PolyFillTypeNegative,
       JoinType, JoinTypeSquare, JoinTypeRound, JoinTypeMiter,
       EndType, EndTypeClosedPolygon, EndTypeClosedLine, EndTypeOpenSquare, EndTypeOpenRound, EndTypeOpenButt,
       Clip, add_path!, add_paths!, execute, clear!, get_bounds,
       IntPoint, IntRect, orientation, area, pointinpolygon, ClipperOffset,
       PolyNode, execute_pt, contour, ishole, contour, children

end
