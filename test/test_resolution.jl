using Test
using ReferenceTests
using GetDP

include("../test/normalized.jl")


@testset "Resolution Generation" begin
    
    resolution = Resolution()
    sys_mag = SystemItem("Sys_Mag", "Darwin_2D"; 
        Type="Complex", 
        Frequency="Freq"
    )
    # Add a resolution
    add!(resolution, "Darwin", [sys_mag],
        Operation=[
            "CreateDir[\"res\"]",
            "InitSolution[Sys_Mag]",
            "Generate[Sys_Mag]", 
            "Solve[Sys_Mag]", 
            "SaveSolution[Sys_Mag]",
            "PostOperation[Mag_Maps]",
            "PostOperation[Mag_Global]"
        ])

    generated_code = code(resolution)
    # Test against reference file
    @test_reference "references/resolution.txt" generated_code by=normalize_exact
end