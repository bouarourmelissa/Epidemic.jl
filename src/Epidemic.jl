module Epidemic
<<<<<<< HEAD
using Agents
using Random
#using CairoMakie
#using DataFrames
include("agent.jl")
=======

using Agents
using Random

include("agent.jl")

# Public API
export HealthStatus, susceptible, exposed, infected, recovered
export Person, ModelParams
export initialize_model, agent_step!

>>>>>>> 3985c7dd32de6d2a6d128fec98a8b0b5bf9c38dd
end
