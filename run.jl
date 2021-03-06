using Glob: glob
using Distributed: procs, addprocs
using Distributed: @everywhere
if length(procs()) <= 2
    addprocs(Sys.CPU_THREADS-2)
    println("$(length(procs())) procs running.")
end
@everywhere include("utils.jl")
@everywhere include("gru_api(seq_to_vec).jl")
@everywhere include("neuroevo.jl")


@everywhere const in_size       = 52
@everywhere const layers        = [50]
@everywhere const out_size      = 10

@everywhere const learning_rate = .01
@everywhere const hm_epochs     = 10



create_model_definitions(layers)

const model = Model(mk_layers(in_size, layers, out_size)...)

const data = import_data(glob("class*.txt")[1])

# const data = [[[randn(1, in_size) for i in 1:rand(1:16)], softmax(randn(1, out_size))] for _ in 1:100]

# TODO read .txts here



for i in 1:hm_epochs
    print("epoch: $i ")
    train!(model, data, learning_rate)
end



        #####     #####



@everywhere const class = 4

@everywhere const hm_initial     = 2_000#10_000
@everywhere const hm_population  = 250#5_000
@everywhere const hm_mostfit     = 100#100
@everywhere const hm_offspring   = 4

@everywhere const track_length   = 8
@everywhere const size_per_time  = in_size
@everywhere const hm_classes     = out_size

@everywhere const hm_generations = 10
@everywhere const hm_total_loop  = 1_000

@everywhere const crossover_prob = .2
@everywhere const mutate_prob    = .3
@everywhere const mutate_rate    = .2
@everywhere const update_rate    = .1



population = [noise(track_length, size_per_time) for _ in 1:hm_initial]



loop(population, hm_loop, hm_generations) =
begin
    loss_init = sum(scores(model, mostfit(population, hm_mostfit, model, class), class))
    # @show loss_init

    for i in 1:hm_loop
        print("loop: ",i," ")
        @time population, loss = evolve(population, hm_generations)
        println("Progress: ", (1-loss/loss_init)*100)
    end
population
end



population = loop(population, hm_total_loop, hm_generations)
