
extends RefCounted
class_name Text


static func localize(loc: LocalizedString) -> String:
    if loc == null:
        return ""

    if loc is LocalizedString:
        var t := TranslationServer.translate(loc.key)
        if t == loc.key:
            return loc.fallback
        return t

    if typeof(loc) == TYPE_STRING_NAME:
        return TranslationServer.translate(loc.key)

    return str(loc)