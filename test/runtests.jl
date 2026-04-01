using ECAD
using Test
using Aqua
using JET

@testset "ECAD.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(ECAD)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(ECAD; target_modules = (ECAD,))
    end
    # Write your tests here.
end
