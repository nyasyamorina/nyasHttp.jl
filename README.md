# nyasHttp.jl

Override [HTTP.jl](https://juliaweb.github.io/HTTP.jl) with default/temporary options.

---

[About kwargs](https://juliaweb.github.io/HTTP.jl/stable/client/#Keyword-Arguments)

### Example

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