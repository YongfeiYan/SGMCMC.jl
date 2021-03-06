"""
A HMC implementation where the kinetic energy is motiviated by relativistic kinetic energy with thermostat extension following

X. Lu, V. Perrone, L. Hasenclever, Y. W. Teh, Sebastian J. Vollmer relativistic Monte Carlo https://arxiv.org/abs/1609.04388


Fields:
    - x: position
    - p: momentum
    - xi: scalar factor for the thermostat
    - ntiers: number of iteration
    - mass: diagonal mass matrix
    - c: speed of light
    - D: diagonal preconditioner
    - independent_momenta: true means kinetic energy is applied to each component of momenta
                           false mean kinetic energy is applied to euclidean length of momenta
Constructors:
    - construct using `RelSGNHTState(x::Array{Float64,1},p::Array{Float64,1},stepsize::Float64; mass=ones(length(x)),c=[1.0], D=[1.0], xi=[1.0], independent_momenta=true)`

"""

type RelSGNHTState <: SamplerState
    x::Array{Float64,1}
    p::Array{Float64,1}
    xi::Array{Float64,1}

    t::Int64
    stepsize::Function
    mass::Array{Float64,1}
    c::Array{Float64,1}
    D::Array{Float64,1}
    independent_momenta::Bool
    """
    Constructs a RelSGNHTState given an initial state, momentum and a fixed stepsize
    """
    function RelSGNHTState(x::Array{Float64,1},p::Array{Float64,1},stepsize::Float64; mass=ones(length(x)),c=[1.0], D=[1.0], xi=[1.0], independent_momenta=true)
        # momentum, mass and state need to have the same size.
        @assert size(x) == size(p)
        @assert size(mass) == size(x)
        # D matrix should be scalar or have the same size as x
        @assert size(x) == size(D) || length(D) == 1
        @assert size(x) == size(c) || length(c) == 1
        # stepsize is used as a function
        s(niters) = stepsize

    new(x,p,xi,0,s,mass,c,D,independent_momenta)
    end
    """
    Constructs a RelSGNHTState given an initial state, momentum and a stepsize schedule
    """
    function RelSGNHTState(x::Array{Float64,1},p::Array{Float64,1},stepsize::Function; mass=ones(length(x)),c=[1.0], D=[1.0], xi=[1.0], independent_momenta=true)
        # momentum, mass and state need to have the same size.
        @assert size(x) == size(p)
        @assert size(mass) == size(x)
        # D matrix should be scalar or have the same size as x
        @assert size(x) == size(D) || length(D) == 1
        @assert size(x) == size(c) || length(c) == 1
        new(x,p,xi,0,stepsize,mass,c,D,independent_momenta)
    end
    """
    Constructs a RelSGNHTState given an initial state and a fixed stepsize
    """
    function RelSGNHTState(x::Array{Float64,1},stepsize::Float64; mass=ones(length(x)),c=[1.0], D=[1.0], xi=[1.0], independent_momenta=true)
        # momentum, mass and state need to have the same size.
        @assert size(mass) == size(x)
        # D matrix should be scalar or have the same size as x
        @assert size(x) == size(D) || length(D) == 1
        @assert size(x) == size(c) || length(c) == 1
        if independent_momenta
            p=zeros(length(x))
            for i=1:length(x) p[i]=sample_rel_p(mass,c,1)[1]  end
        else
            p = sample_rel_p(mass, c, length(x))
        end
        # stepsize is used as a function
        s(niters) = stepsize

    new(x,p,xi,0,s,mass,c,D,independent_momenta)
    end
    """
    Constructs a RelSGNHTState given an initial state and a stepsize schedule
    """
    function RelSGNHTState(x::Array{Float64,1},stepsize::Function; mass=ones(length(x)),c=[1.0], D=[1.0], xi=[1.0], independent_momenta=true)
        @assert size(mass) == size(x)
        # D matrix should be scalar or have the same size as x
        @assert size(x) == size(D) || length(D) == 1
        @assert size(x) == size(c) || length(c) == 1
        if independent_momenta
            p=zeros(length(x))
            for i=1:length(x) p[i]=sample_rel_p(mass,c,1)[1]  end
        else
            p = sample_rel_p(mass, c, length(x))
        end
        new(x,p,xi,0,stepsize,mass,c,D,independent_momenta)
    end
end


function sample!(s::RelSGNHTState, grad)
    #increase iteration counter
    s.t += 1

    # improve readability
    x = s.x
    p = s.p
    D = s.D
    t = s.t
    stepsize = s.stepsize(t)
    xi = s.xi
    m = s.mass
    c = s.c
    independent_momenta=s.independent_momenta

    tmp = zeros(length(x))
    if independent_momenta
        tmp = m .* sqrt(p.^2 ./ (m.^2 .* c.^2) + 1)
    else
        tmp = m .* sqrt(p'p ./ (m.^2 .* c.^2) + 1)
    end

    n = sqrt(stepsize.*(2*D)).*randn(length(x)) # noise term

    #update momentum
    p[:] += stepsize.*(grad(x)-xi.*p./tmp) + n
    #update tmp

    if independent_momenta
        tmp = m .* sqrt(p.^2 ./ (m.^2 .* c.^2) + 1)
    else
        tmp = m .* sqrt(p'p ./ (m.^2 .* c.^2) + 1)
    end
    #update state
    x[:] += stepsize.*p./tmp

    #update thermostats
    if independent_momenta
        xi[:]+=stepsize.*(p'*(p.*(1./(tmp.^2) + 1./(c.^2.*tmp.^3)))./length(x) - 1./length(x).*sum(1./tmp))
    else
        xi[:]+=stepsize.* (p'*p./length(x).*(1./tmp.^2 + 1./(tmp.^3 .* c.^2)) - 1./tmp)
    end
    s
end
