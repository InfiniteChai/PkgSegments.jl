module PkgSegments

import TOML
import UUIDs

"""
    PackageKey

A helper struct for capturing and parsing bacic information
about a package. Either using the naming convention of
PkgName or PkgName:UUID to uniquely identify the package within
the project
"""
struct PackageKey
    name::String
    uuid::Union{Nothing, UUIDs.UUID}

    function PackageKey(name::AbstractString)
        parts = split(name, ":")
        if length(parts) == 1
            PackageKey(parts[1], nothing)
        elseif length(parts) == 2
            PackageKey(parts[1], parts[2])
        else
            throw("Unable to construct PackageKey from $name")
        end
    end
    PackageKey(name::AbstractString, uuid::Nothing) = new(name, nothing)
    PackageKey(name::AbstractString, uuid::AbstractString) = new(name, UUIDs.UUID(uuid))
    PackageKey(name::AbstractString, uuid::UUIDs.UUID) = new(name, uuid)
    PackageKey(params::Pair{String, Any}) = PackageKey(params.first, params.second)
end

"""
    Base.:(==)(k1::PackageKey, k2::PackageKey)

Overrides equality of the PackageKey so that if the UUID is not defined
then the name is used solely for identifying equality.
"""
function Base.:(==)(k1::PackageKey, k2::PackageKey)
    if k1.uuid === nothing || k2.uuid === nothing
        k1.name == k2.name
    else
        k1.name == k2.name && k1.uuid == k2.uuid
    end
end

"""
    Base.hash(k::PackageKey, h::UInt64)

Override the hash inline with the equality function, so that we just
generate the hash from the name.
"""
Base.hash(k::PackageKey, h::UInt64) = hash(k.name, h)

"""
    generatesegment!(directory::AbstractString, deps::Set{PackageKey}; subdir::AbstractString="seg")

Generate the segmented Manifest.toml and Project.toml in given directory
based on the desired dependencies.
"""
function generatesegment!(directory::AbstractString, deps::Set{PackageKey}; subdir::AbstractString="seg")
    mkpath(joinpath(directory, subdir))
    open(joinpath(directory, subdir, "Project.toml"), "w") do io
        TOML.print(io, projectsegment(directory, deps))
    end

    open(joinpath(directory, subdir, "Manifest.toml"), "w") do io
        TOML.print(io, manifestsegment(directory, deps))
    end
end

"""
    genfromsegfile!(directory::AbstractString)

Uses a PkgSegments.toml file in the directory to specify the segments
to generate. Each section should specify the `deps` as an array and the
subdir to create the files as `subdir`
"""
function genfromsegfile!(directory::AbstractString)
    segments = TOML.parsefile(joinpath(directory, "PkgSegments.toml"))
    for (name, segment) in segments
        deps = Set([PackageKey(k) for k in segment["deps"]])
        generatesegment!(directory, deps; subdir=segment["subdir"])
    end
end

function projectsegment(directory::AbstractString, deps::Set{PackageKey})
    alldeps = copy(deps)
    # Make sure we include julia, which is pretty much a guarantee.
    push!(alldeps, PackageKey("julia"))
    data = TOML.parsefile(joinpath(directory, "Project.toml"))
    # Now we work through the dependencies and associated compats.
    for entry in data["deps"]
        key = PackageKey(entry)
        if key ∉ deps
            delete!(data["deps"], entry[1])
            if entry[1] in keys(data["compat"])
                delete!(data["compat"], entry[1])
            end
        end
    end

    data
end


function manifestsegment(directory::AbstractString, deps::Set{PackageKey})
    alldeps = copy(deps)
    data = TOML.parsefile(joinpath(directory, "Manifest.toml"))

    depqueue = collect(alldeps)
    while length(depqueue) > 0
        key = pop!(depqueue)
        entries = data[key.name]
        if key.uuid !== nothing
            entries = [e for e in entries if UUIDs.UUID(e["uuid"]) == key.uuid]
        end
        length(entries) != 1 && error("Unable to identify unique package for $key")
        entry = entries[1]
        deps = [PackageKey(d) for d in get(entry, "deps", [])]
        append!(depqueue, deps)
        for dep in deps
            push!(alldeps, dep)
        end
    end

    for (name, info) in data
        subentries = [s for s in info if PackageKey(name, s["uuid"]) ∈ alldeps]
        if length(subentries) > 0
            data[name] = subentries
        else
            delete!(data, name)
        end
    end

    data
end


end # module
