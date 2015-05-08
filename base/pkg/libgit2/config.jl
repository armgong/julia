type GitConfig
    ptr::Ptr{Void}

    function GitConfig(ptr::Ptr{Void})
        @assert ptr != C_NULL
        cfg = new(ptr)
        finalizer(cfg, free!)
        return cfg
    end
end

function free!(cfg::GitConfig)
    if cfg.ptr != C_NULL
        ccall((:git_config_free, :libgit2), Void, (Ptr{Void},), cfg.ptr)
        cfg.ptr = C_NULL
    end
end

function GitConfig(path::AbstractString)
    cfg_ptr_ptr = Ref{Ptr{Void}}(C_NULL)
    err = ccall((:git_config_open_ondisk, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Uint8}), cfg_ptr_ptr, path)
    err !=0 && return nothing
    return GitConfig(cfg_ptr_ptr[])
end

function GitConfig(r::GitRepo)
    cfg_ptr_ptr = Ref{Ptr{Void}}(C_NULL)
    err = ccall((:git_repository_config, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), cfg_ptr_ptr, r.ptr)
    err !=0 && return nothing
    return GitConfig(cfg_ptr_ptr[])
end

function GitConfig()
    cfg_ptr_ptr = Ref{Ptr{Void}}(C_NULL)
    ccall((:git_config_open_default, :libgit2), Cint,
          (Ptr{Ptr{Void}}, ), cfg_ptr_ptr)
    return GitConfig(cfg_ptr_ptr[])
end

function lookup{T<:AbstractString}(::Type{T}, c::GitConfig, name::AbstractString)
    str_ptr = Ref{Ptr{Uint8}}(C_NULL)
    err = ccall((:git_config_get_string, :libgit2), Cint,
                (Ptr{Ptr{Uint8}}, Ptr{Void}, Ptr{Uint8}), str_ptr, c.ptr, name)
    if err == GitErrorConst.GIT_OK
        return bytestring(str_ptr[])
    else
        return nothing
    end
end

function set!{T}(c::GitConfig, name::AbstractString, value::T)
    err = if T<:AbstractString
        ccall((:git_config_set_string, :libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), c.ptr, name, value)
    elseif is(T, Bool)
        bval = Int32(value)
        ccall((:git_config_set_bool, :libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}, Cint), c.ptr, name, bval)
    elseif is(T, Int32)
        ccall((:git_config_set_int32, :libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}, Cint), c.ptr, name, value)
    elseif is(T, Int64)
        ccall((:git_config_set_int64, :libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}, Cintmax_t), c.ptr, name, value)
    else
        warn("Type $T is not supported")
    end
    return err
end
