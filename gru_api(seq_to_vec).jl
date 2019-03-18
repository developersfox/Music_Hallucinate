using Random: shuffle
using Distributed: @everywhere, @distributed
@everywhere include("gru_dynamic_struct.jl")



create_model_definitions(layer) =
begin
    eval(Meta.parse("@everywhere " * "struct Model\n" * *(["l$i::Layer\n" for i in 1:length(layers) +1]...) * "end"))
    eval(Meta.parse("@everywhere " * "(model::Model)(io) =\n" * "begin\n" * *(["io = model.l$i(io)\n" for i in 1:length(layers) +1]...) * "end"))
end


soften = arr -> (begin
    soft_arr = softmax(arr[1:Int(length(arr)/4)])
    for (i,e) in enumerate(soft_arr)
        arr[i] = e
    end
arr
end)

prop(model, x) =
begin
    for mfield in fieldnames(Model)
        layer = getfield(model, mfield)
        layer.state = zeros(1, length(layer.bs))
    end
soften([model(t) for t in x][end])
end



train!(model, datas, lr) =
begin

    result = @distributed vcat for (x,y) in shuffle(datas)
        d = @diff cross_entropy(prop(model, x), y)
        grads = []
        for mfield in fieldnames(Model)
            layer = getfield(model, mfield)
            for lfield in fieldnames(Layer)
                push!(grads, grad(d, getfield(layer, lfield)))
            end
        end
        grads, value(d)
    end

    loss = 0.0
    for (g,l) in result
        loss += l
        i = 0
        for mfield in fieldnames(Model)
            layer = getfield(model, mfield)
            for lfield in fieldnames(Layer)
                i +=1
                setfield!(layer, lfield, Param(getfield(layer, lfield) - g[i] .* lr))
            end
        end
    end
    @show loss
end
