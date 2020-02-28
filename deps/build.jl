using ADCME
function compile(DIR)
    PWD = pwd()
    cd(DIR)
    rm("build", force=true, recursive=true)
    try
	mkdir("build")
    catch
	end

    cd("build")
    ADCME.cmake()
    ADCME.make()
    cd(PWD)
end


compile("$(@__DIR__)/DirichletBD")
compile("$(@__DIR__)/FemStiffness")
compile("$(@__DIR__)/Strain")
compile("$(@__DIR__)/StrainEnergy")
compile("$(@__DIR__)/SpatialFemStiffness")