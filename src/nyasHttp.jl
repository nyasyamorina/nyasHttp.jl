"""
    nyasHttp

Override HTTP.jl with default/temporary options.
[About kwargs](https://juliaweb.github.io/HTTP.jl/stable/client/#Keyword-Arguments)

```julia
using nyasHttp

nyasHttp.get("https://www.google.com/404")  # error

setoptions!(; status_exception = false)
nyasHttp.get("https://www.google.com/404")  # no error

# or you can do this
tempoptions(; status_exception = true) do
    nyasHttp.get("https://www.google.com/404")  # error
end
getkwarg(:status_exception) # -> false
```
"""
module nyasHttp

using HTTP

export RequestOptions, getheader, getkwarg, setheader!, setkwarg!, setoptions!, tempoptions


"store the default headers and kwargs will pass into `HTTP`"
struct RequestOptions
    headers::Dict{String, String}
    kwargs::Dict{Symbol, Any}
end

function RequestOptions(headers = Pair[]; kwargs...)
    h = Dict{String, String}()
    for (key, value) ∈ headers
        h[string(key)] = string(value)
    end
    k = Dict{Symbol, Any}(kwargs)
    return RequestOptions(h, k)
end

function Base.getproperty(opts::RequestOptions, sym::Symbol)
    sym ∈ fieldnames(RequestOptions) && return getfield(opts, sym)
    return getkwarg(opts, sym)
end
function Base.setproperty!(opts::RequestOptions, sym::Symbol, value)
    sym ∈ fieldnames(RequestOptions) && return setfield!(opts, sym, value)
    return setkwarg!(opts, sym, value)
end

getheader(opts::RequestOptions, key) = Base.get(opts.headers, string(key), missing)
getkwarg(opts::RequestOptions, sym) = Base.get(opts.kwargs, sym, missing)

setheader!(opts::RequestOptions, key, value) = (opts.headers[string(key)] = string(value); opts)
setkwarg!(opts::RequestOptions, sym::Symbol, value) = (opts.kwargs[sym] = value; opts)

deleteheader!(opts::RequestOptions, key) = delete!(opts.headers, key)
deletekwarg!(opts::RequestOptions, sym::Symbol) = delete!(opts.kwargs, sym)

function setoptions!(opts::RequestOptions, headers = Pair[]; kwargs...)
    for (key, value) ∈ headers
        opts.headers[string(key)] = string(value)
    end
    for (sym, value) ∈ kwargs
        opts.kwargs[sym] = value
    end
    return opts
end
setoptions!(opts::RequestOptions, others::RequestOptions) = setoptions!(opts, others.headers; others.kwargs...)

function tempoptions(f, opts::RequestOptions, headers = Pair[]; kwargs...)
    # record whats will change and change it
    restore_headers = Dict{String, Union{String, Missing}}()
    restore_kwargs = Dict{Symbol, Any}()
    for (key, value) ∈ headers
        key_s = string(key)
        restore_headers[key_s] = Base.get(opts.headers, key_s, missing)
        opts.headers[key_s] = string(value)
    end
    for (sym, value) ∈ kwargs
        restore_kwargs[sym] = Base.get(opts.kwargs, sym, missing)
        opts.kwargs[sym] = value
    end
    try

        return f()

    # restore what changed
    finally
        for (key, value) ∈ restore_headers
            value ≡ missing && (delete!(opts.headers, key); continue)
            opts.headers[key] = value
        end
        for (sym, value) ∈ restore_kwargs
            value ≡ missing && (delete!(opts.kwargs, sym); continue)
            opts.kwargs[sym] = value
        end
    end
end
tempoptions(f, opts::RequestOptions, others::RequestOptions) = tempoptions(f, opts, others.headers; others.kwargs...)

"see also `HTTP.request`"
function request(opts::RequestOptions, method, url, h = nothing, b = HTTP.nobody; headers = h, body = b, kwargs...)
    h = opts.headers
    if headers ≢ nothing
        h = copy(opts.headers)
        for (key, value) ∈ headers
            h[string(key)] = string(value)
        end
    end
    k = opts.kwargs
    if ~isempty(kwargs)
        k = copy(opts.kwargs)
        for (sym, value) ∈ kwargs
            k[sym] = value
        end
    end
    return HTTP.request(method, url, h, body; k...)
end
"see also `HTTP.open`"
open(f, opts::RequestOptions, method, url, headers = nothing; kwargs...) = request(opts, method, url, headers; iofunction = f, kwargs...)


const default_options = RequestOptions()

getheader(key) = getheader(default_options, key)
getkwarg(sym) = getkwarg(default_options, sym)
setheader!(key, value) = setheader!(default_options, key, value)
setkwarg!(sym::Symbol, value) = setkwarg!(default_options, sym, value)
setoptions!(headers = Pair[]; kwargs...) = setoptions!(default_options, headers; kwargs...)
deleteheader!(key) = deleteheader!(default_options, key)
deletekwarg!(sym::Symbol) = deletekwarg!(default_options, sym)
tempoptions(f, headers = Pair[]; kwargs...) = tempoptions(f, default_options, headers; kwargs...)
open(f, method, url, headers = nothing; kwargs...) = request(f, default_options, method, url, headers; kwargs...)


for func ∈ (:get, :put, :post, :patch, :head, :delete)
    method = uppercase(string(func))
    @eval $func(opts::RequestOptions, a...; kw...) = request(opts, $method, a...; kw...)
    @eval $func(a...; kw...) = $func($default_options, a...; kw...)
end

end # nyasHttp