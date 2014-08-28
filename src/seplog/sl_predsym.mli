include Util.BasicType 

module Set : Util.OrderedContainer with type elt = t
module MSet : Util.OrderedContainer with type elt = t

val mk : string -> t
val parse : (t, 'a) MParser.parser
val of_string : string -> t
val to_melt : t -> Latex.t