import PkgSegments
using Test
using TOML

@testset "PkgSegments" verbose=true begin
    @testset "Segment Cases" begin
        cases = TOML.parsefile("resources/test_cases.toml")
        for (case, segments) in cases
            project = TOML.parsefile(joinpath(".", "resources", segments["project"]))
            manifest = TOML.parsefile(joinpath(".", "resources", segments["manifest"]))

            for (segment, data) in segments
                segment in ("project", "manifest") && continue
                deps = Set{PkgSegments.PackageKey}([PkgSegments.PackageKey(d) for d in data["deps"]])
                (smanifest, sproject) = PkgSegments.segmentdata(project, manifest, deps)

                @test sproject == TOML.parsefile(joinpath("./resources", data["segment_project"]))
                @test smanifest == TOML.parsefile(joinpath("./resources", data["segment_manifest"]))
            end
        end
    end

    @testset "Remaps" begin
        data1 = Dict(
            "foo" => [
                Dict("val" => 1, "uuid" => "8cdd6a97-d057-4071-95f6-34d483f09739"),
                Dict("val" => 2, "uuid" => "f2538692-aebe-4c64-9b8c-4ed79cebc4af"),
            ],
            "bar" => [
                Dict("val" => 1, "uuid" => "83ccafeb-64f4-4d6c-8f81-627277edf5bc"),
            ]
        )

        data2 = Dict(
            PkgSegments.PackageKey("foo", "8cdd6a97-d057-4071-95f6-34d483f09739") =>
                Dict("val" => 1, "uuid" => "8cdd6a97-d057-4071-95f6-34d483f09739"),
            PkgSegments.PackageKey("foo", "f2538692-aebe-4c64-9b8c-4ed79cebc4af") =>
                Dict("val" => 2, "uuid" => "f2538692-aebe-4c64-9b8c-4ed79cebc4af"),
            PkgSegments.PackageKey("bar", "83ccafeb-64f4-4d6c-8f81-627277edf5bc") =>
                Dict("val" => 1, "uuid" => "83ccafeb-64f4-4d6c-8f81-627277edf5bc"),
        )

        @test PkgSegments.manifesttokey(data1) == data2
        d = PkgSegments.keytomanifest(data2)
        for key in ∪(keys(d), keys(data1))
            @test issetequal(get(d, key, []), get(data1, key, []))
        end
    end
end
